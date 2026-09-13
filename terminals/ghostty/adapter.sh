#!/usr/bin/env bash
# Ghostty. One rendered file, ~/.config/ghostty/nekoshell, which Ghostty reads
# through a single `config-file = nekoshell` line in its main config. Ghostty
# has no escape for changing a running window's colours or background and no
# way to give its quick terminal a command of its own, so the file is the
# whole story on this side: ⌥M toggles the quick terminal, and
# terminals/ghostty/zsh.zsh, sourced by the shell that starts inside it, is
# what turns that into the music panel. terminals/adapter.sh is sourced first
# and this file overrides what it supports.

GHOSTTY_DIR="$HOME/.config/ghostty"
GHOSTTY_OWNED="$GHOSTTY_DIR/nekoshell"
GHOSTTY_CONFIG="$GHOSTTY_DIR/config"
# The include line and the comment that tags it as ours. Ghostty reads a
# trailing `# nekoshell` on a config-file line as part of the path (its
# validator reports "nekoshell # nekoshell: FileNotFound"), so the tag is a
# line of its own directly above; the two are added and stripped as a pair.
GHOSTTY_MARKER="# nekoshell"
GHOSTTY_INCLUDE="config-file = nekoshell"
GHOSTTY_HOTKEY="keybind = global:alt+m=toggle_quick_terminal"
export GHOSTTY_DIR GHOSTTY_OWNED GHOSTTY_CONFIG GHOSTTY_MARKER GHOSTTY_INCLUDE GHOSTTY_HOTKEY

terminal_name() { echo "ghostty"; }
# Ghostty exports GHOSTTY_RESOURCES_DIR in every shell it starts; TERM_PROGRAM
# is the fallback for a shell that scrubbed its environment.
terminal_detect() { [[ -n "${GHOSTTY_RESOURCES_DIR:-}" || "${TERM_PROGRAM:-}" == "ghostty" ]]; }
# The app bundle, or a `ghostty` someone linked onto PATH (the bundle's own
# CLI at Contents/MacOS/ghostty is not on PATH by default).
terminal_installed() {
  [[ -e "/Applications/Ghostty.app" || -e "$HOME/Applications/Ghostty.app" ]] || command -v ghostty >/dev/null 2>&1
}
# images: Ghostty draws the kitty graphics protocol, which fastfetch --kitty
# speaks. hotkey and panel: the global ⌥M keybind and the quick terminal.
terminal_capabilities() { echo "truecolor images background panel hotkey"; }
# The family name Ghostty's own discovery reports for the Nerd Font
# (`ghostty +list-fonts --family="JetBrainsMono Nerd Font"`), which is what
# font-family wants; the PostScript spelling iTerm2 uses is not found here.
terminal_font_name() { echo "JetBrainsMono Nerd Font"; }

# _ghostty_setting KEY: KEY from nekoshell.toml, or nothing. Tolerates a shell
# where config.sh was never sourced (the adapter is also loadable on its own).
_ghostty_setting() {
  local v=""
  command -v config_get >/dev/null 2>&1 && v="$(config_get "$1" 2>/dev/null || true)"
  printf '%s' "$v"
}

# _ghostty_flavor: the flavour to render, whatever the caller knows about themes.
_ghostty_flavor() {
  local f=""
  command -v theme_current >/dev/null 2>&1 && f="$(theme_current 2>/dev/null || true)"
  [[ -n "$f" ]] || f="$(_ghostty_setting theme_resolved)"
  [[ -n "$f" ]] || f="mocha"
  printf '%s' "$f"
}

# _ghostty_opacity_ok OPACITY: a decimal from 0 to 1 and nothing else. Ghostty
# accepts values above 1 for background-image-opacity and gives them a meaning
# of their own (the image brighter than the base colour), which is not what a
# caller asking for "1.5" meant, so the same range as iTerm2 is enforced here.
_ghostty_opacity_ok() { [[ "$1" =~ ^(0|1|0?\.[0-9]+|1\.0+)$ ]]; }

# _ghostty_abspath PATH: PATH as an absolute, symlink-resolved path. Ghostty
# resolves a relative background-image against its own working directory,
# not the shell's, so a relative path would silently show no image.
_ghostty_abspath() {
  local p="$1"
  [[ "$p" == /* ]] || p="$PWD/$p"
  if [[ -e "$p" ]]; then
    p="$(cd "$(dirname "$p")" && pwd -P)/$(basename "$p")"
  fi
  printf '%s' "$p"
}

# _ghostty_background_lines PATH OPACITY: the config lines for a background
# image, or nothing for an empty PATH. background-image-opacity is relative to
# background-opacity, which the template leaves at 1, so OPACITY goes in as it
# is: 1 shows the image untouched, 0.85 lays a little of the base colour over it.
_ghostty_background_lines() {
  [[ -n "$1" ]] || return 0
  printf '\n# Background image, from: nekoshell terminal background\n'
  printf 'background-image = %s\nbackground-image-opacity = %s\nbackground-image-fit = cover\n' "$1" "$2"
}

# ghostty_write_config [FLAVOR] [BACKGROUND OPACITY]: render the owned file.
# The template carries every colour as a placeholder; the font name and the
# background lines are filled in here so the font comes from terminal_font_name
# rather than a second literal. Built beside the destination and renamed into
# place, so a failure part way through never leaves Ghostty a half-written
# file to complain about at launch.
ghostty_write_config() {
  local flavor="${1:-mocha}" bg="${2:-}" opacity="${3:-0.85}" tmp
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would render $GHOSTTY_OWNED ($flavor${bg:+, background $bg at $opacity})"
    return 0
  fi
  run mkdir -p "$GHOSTTY_DIR"
  tmp="$GHOSTTY_OWNED.tmp"
  theme_render_template "$NEKOSHELL_ROOT/terminals/ghostty/nekoshell.tmpl" "$tmp" "$flavor" || return 1
  {
    awk -v font="$(terminal_font_name)" '{ sub(/@@FONT@@/, font) } 1' "$tmp"
    _ghostty_background_lines "$bg" "$opacity"
  } >"$tmp.2" && mv "$tmp.2" "$GHOSTTY_OWNED"
  rm -f "$tmp"
  log_info "rendered $GHOSTTY_OWNED ($flavor)"
}

# _ghostty_has_include: true when the main config already reads our file.
_ghostty_has_include() { [[ -f "$GHOSTTY_CONFIG" ]] && grep -qxF "$GHOSTTY_INCLUDE" "$GHOSTTY_CONFIG"; }

# _ghostty_backup_config: the user's own main config into the backup set once,
# before the first edit. backup_path moves the file, so it is copied straight
# back: the include line goes into the copy, the original sits in the backup
# and uninstall's restore puts it back over ours. A second apply never gets
# here, because the include line is already in place by then.
_ghostty_backup_config() {
  local rel=".config/ghostty/config"
  [[ -f "$GHOSTTY_CONFIG" && ! -L "$GHOSTTY_CONFIG" ]] || return 0
  if ! command -v backup_path >/dev/null 2>&1; then
    log_warn "no backup library loaded; $rel is edited without a backup"
    return 0
  fi
  [[ -n "${NEKOSHELL_BACKUP_DIR:-}" ]] || backup_begin
  log_info "backing up your $rel before adding the include line"
  backup_path "$rel"
  run cp "$NEKOSHELL_BACKUP_DIR/$rel" "$GHOSTTY_CONFIG"
}

# _ghostty_add_include: one tagged include line in the main config, creating
# the file when there is none. Runs on every apply and adds nothing the second
# time, which is what keeps apply idempotent. Appended at the end because
# Ghostty applies an included file after the file that names it, so anything
# the user wrote above still wins over nothing, and the README says to put
# overrides below the line.
_ghostty_add_include() {
  _ghostty_has_include && return 0
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would add '$GHOSTTY_INCLUDE' to $GHOSTTY_CONFIG"
    return 0
  fi
  _ghostty_backup_config
  mkdir -p "$GHOSTTY_DIR"
  # A config whose last line has no newline would otherwise swallow the marker.
  if [[ -s "$GHOSTTY_CONFIG" && -n "$(tail -c 1 "$GHOSTTY_CONFIG")" ]]; then
    printf '\n' >>"$GHOSTTY_CONFIG"
  fi
  printf '%s\n%s\n' "$GHOSTTY_MARKER" "$GHOSTTY_INCLUDE" >>"$GHOSTTY_CONFIG"
  log_info "added '$GHOSTTY_INCLUDE' to $GHOSTTY_CONFIG"
}

# _ghostty_remember PATH OPACITY: record the background in nekoshell.toml, so
# the next theme switch, which regenerates the owned file from scratch, writes
# it again. An empty PATH records "none". Skipped on a dry run, and in a shell
# without config.sh, where there is nothing to record into.
_ghostty_remember() {
  [[ "${NEKOSHELL_DRY_RUN:-0}" != "1" ]] || return 0
  command -v config_set >/dev/null 2>&1 || return 0
  config_set background "$1"
  config_set background_opacity "$2"
}

# terminal_apply FLAVOR: the owned file, then the include line. A stored
# background is written again here for the same reason as in iTerm2: the file
# is regenerated from scratch and would otherwise lose it on a theme change.
terminal_apply() {
  local flavor="${1:-mocha}" bg opacity="0.85"
  bg="$(_ghostty_setting background)"
  if [[ -n "$bg" ]]; then
    opacity="$(_ghostty_setting background_opacity)"
    [[ -n "$opacity" ]] || opacity="0.85"
    if ! _ghostty_opacity_ok "$opacity"; then
      log_warn "background_opacity is $opacity, which is not between 0 and 1; using 0.85"
      opacity="0.85"
    fi
    bg="$(_ghostty_abspath "$bg")"
  fi
  ghostty_write_config "$flavor" "$bg" "$opacity" || return 1
  _ghostty_add_include
  log_info "Ghostty reads the new config on ⌘⇧, (reload) or its next launch"
  return 0
}

# terminal_remove: the owned file, and the tagged pair out of the main config.
# The config itself goes only when nothing but our two lines was in it, which
# is the file this adapter created; a config with a line of the user's stays,
# and an include line without our marker above it is theirs and stays too.
terminal_remove() {
  run rm -f "$GHOSTTY_OWNED"
  [[ -f "$GHOSTTY_CONFIG" ]] || return 0
  grep -qxF "$GHOSTTY_MARKER" "$GHOSTTY_CONFIG" || return 0
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would remove '$GHOSTTY_INCLUDE' from $GHOSTTY_CONFIG"
    return 0
  fi
  # A marker is held back one line: dropped with the include that follows it,
  # printed again when something else does.
  awk -v m="$GHOSTTY_MARKER" -v i="$GHOSTTY_INCLUDE" '
    held { held = 0; if ($0 == i) next; print m }
    $0 == m { held = 1; next }
    { print }
    END { if (held) print m }' "$GHOSTTY_CONFIG" >"$GHOSTTY_CONFIG.tmp" && mv "$GHOSTTY_CONFIG.tmp" "$GHOSTTY_CONFIG"
  log_info "removed '$GHOSTTY_INCLUDE' from $GHOSTTY_CONFIG"
  if ! grep -q '[^[:space:]]' "$GHOSTTY_CONFIG"; then
    run rm -f "$GHOSTTY_CONFIG"
  fi
  return 0
}

# terminal_background PATH|none [OPACITY]: the background-image lines in the
# owned file, and the path in nekoshell.toml so the next apply keeps it. No
# live change: Ghostty has no escape for it, so the image shows after a reload.
terminal_background() {
  local path="${1:-}" opacity="${2:-0.85}" flavor
  [[ -n "$path" ]] || {
    log_fail "usage: nekoshell terminal background PATH|none [OPACITY]"
    return 1
  }
  flavor="$(_ghostty_flavor)"
  if [[ "$path" == "none" ]]; then
    ghostty_write_config "$flavor" || return 1
    _ghostty_remember "" ""
  else
    _ghostty_opacity_ok "$opacity" || {
      log_fail "opacity must be between 0 and 1"
      return 1
    }
    path="$(_ghostty_abspath "$path")"
    [[ -e "$path" ]] || log_warn "$path does not exist yet; writing it into the config anyway"
    ghostty_write_config "$flavor" "$path" "$opacity" || return 1
    _ghostty_remember "$path" "$opacity"
  fi
  log_info "Ghostty shows the change on ⌘⇧, (reload) or its next launch"
  return 0
}

# terminal_panel CMD...: the quick terminal is already the panel and cannot
# be handed a command from here, so outside tmux there is nothing to open —
# say which key opens it and run the command in this window.
terminal_panel() {
  if [[ -n "${TMUX:-}" ]]; then
    terminal_panel_default "$@"
  else
    log_info "press ⌥M to toggle the panel; running here"
    "$@"
  fi
}

# terminal_doctor: the owned file and its flavour, the include line, the font
# the file names, and the hotkey line. The hotkey row warns rather than passes
# because the one thing that decides whether ⌥M works, the Accessibility
# permission Ghostty's keybind docs require for a global: binding, is granted
# in System Settings and cannot be read from here.
terminal_doctor() {
  local flavor head="" font="" hotkey=1
  flavor="$(_ghostty_flavor)"
  if [[ ! -f "$GHOSTTY_OWNED" ]]; then
    report fail "ghostty config" "missing (run: nekoshell terminal apply)"
  else
    head="$(head -n 1 "$GHOSTTY_OWNED" 2>/dev/null || true)"
    case "$head" in
      *nekoshell*"($flavor)"*) report ok "ghostty config" "$GHOSTTY_OWNED" ;;
      *nekoshell*) report fail "ghostty config" "rendered for another flavour, theme is $flavor; run: nekoshell terminal apply" ;;
      *) report fail "ghostty config" "not rendered by nekoshell; run: nekoshell terminal apply" ;;
    esac
    font="$(awk -F' = ' '$1 == "font-family" { print $2; exit }' "$GHOSTTY_OWNED" 2>/dev/null || true)"
    grep -qxF "$GHOSTTY_HOTKEY" "$GHOSTTY_OWNED" && hotkey=0
  fi

  if _ghostty_has_include; then
    report ok "ghostty include" "$GHOSTTY_CONFIG reads nekoshell"
  else
    report fail "ghostty include" "$GHOSTTY_CONFIG has no '$GHOSTTY_INCLUDE' line; run: nekoshell terminal apply"
  fi

  if [[ -z "$font" ]]; then
    report warn "ghostty font" "no font to read (see the config row)"
  elif [[ "$font" == "$(terminal_font_name)" ]]; then
    report ok "ghostty font" "$font"
  else
    report fail "ghostty font" "$font is not $(terminal_font_name); run: nekoshell terminal apply"
  fi

  if [[ "$hotkey" -eq 0 ]]; then
    report warn "ghostty hotkey" "⌥M toggles the quick terminal once Ghostty has Accessibility permission (System Settings > Privacy & Security > Accessibility)"
  else
    report fail "ghostty hotkey" "no global ⌥M keybind in $GHOSTTY_OWNED; run: nekoshell terminal apply"
  fi
}
