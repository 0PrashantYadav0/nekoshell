#!/usr/bin/env bash
# kitty. Everything is a file: kitty reads ~/.config/kitty/kitty.conf when a
# window opens (or on ctrl+shift+f5), so nekoshell renders its own
# nekoshell.conf next to it and adds one include line to kitty.conf. The music
# panel is kitty's quick-access terminal kitten, configured by a second owned
# file and toggled by alt+m from inside kitty. terminals/adapter.sh is sourced
# first and this file overrides what it supports.

# kitty looks for its config in KITTY_CONFIG_DIRECTORY, then
# $XDG_CONFIG_HOME/kitty, then ~/.config/kitty, so the files go where it looks.
KITTY_CONFIG_DIR="${KITTY_CONFIG_DIRECTORY:-${XDG_CONFIG_HOME:-$HOME/.config}/kitty}"
KITTY_CONF="$KITTY_CONFIG_DIR/kitty.conf"
KITTY_NEKOSHELL_CONF="$KITTY_CONFIG_DIR/nekoshell.conf"
KITTY_PANEL_CONF="$KITTY_CONFIG_DIR/nekoshell-panel.conf"
# The include is two lines: kitty takes everything after `include` as the file
# name, a trailing comment included, so the marker sits on its own line above.
KITTY_INCLUDE_MARK="# nekoshell"
KITTY_INCLUDE_LINE="include nekoshell.conf"
# kitty draws only PNG (and a few other raster formats) as a background; a
# chosen image in another format is converted to this file.
KITTY_BACKGROUND_PNG="${NEKOSHELL_DATA:-$HOME/.local/share/nekoshell}/kitty-background.png"
export KITTY_CONFIG_DIR KITTY_CONF KITTY_NEKOSHELL_CONF KITTY_PANEL_CONF
export KITTY_INCLUDE_MARK KITTY_INCLUDE_LINE KITTY_BACKGROUND_PNG

terminal_name() { echo "kitty"; }
terminal_detect() { [[ -n "${KITTY_WINDOW_ID:-}" || "${TERM:-}" == "xterm-kitty" ]]; }
terminal_installed() {
  [[ -e "/Applications/kitty.app" || -e "$HOME/Applications/kitty.app" ]] || command -v kitty >/dev/null 2>&1
}
terminal_capabilities() { echo "truecolor images background panel hotkey"; }
# The family name as kitty lists it (`kitty +list-fonts`), spaces and all.
terminal_font_name() { echo "JetBrainsMono Nerd Font"; }

# _kitty_setting KEY: KEY from nekoshell.toml, or nothing. Tolerates a shell
# where config.sh was never sourced (the adapter is also loadable on its own).
_kitty_setting() {
  local v=""
  command -v config_get >/dev/null 2>&1 && v="$(config_get "$1" 2>/dev/null || true)"
  printf '%s' "$v"
}

# _kitty_store KEY VALUE: record KEY in nekoshell.toml when config.sh is
# loaded, so the next theme switch renders the same background again.
_kitty_store() {
  command -v config_set >/dev/null 2>&1 || return 0
  config_set "$1" "$2"
}

# _kitty_flavor: the flavour to render, whatever the caller knows about themes.
_kitty_flavor() {
  local f=""
  command -v theme_current >/dev/null 2>&1 && f="$(theme_current 2>/dev/null || true)"
  [[ -n "$f" ]] || f="$(_kitty_setting theme_resolved)"
  [[ -n "$f" ]] || f="mocha"
  printf '%s' "$f"
}

# _kitty_opacity_ok OPACITY: a decimal from 0 to 1 and nothing else. awk would
# read "abc" as 0 and "1.5" as a negative tint, which kitty then clamps or
# ignores, so the check happens before anything is written.
_kitty_opacity_ok() { [[ "$1" =~ ^(0|1|0?\.[0-9]+|1\.0+)$ ]]; }

# _kitty_tint OPACITY: kitty's background_tint for an image shown at OPACITY.
# They are opposites: background_tint is how much of the background colour
# is laid over the image (0 leaves it untouched, 1 hides it), opacity is how
# much of the image shows through.
_kitty_tint() { awk -v o="$1" 'BEGIN { printf "%g\n", 1 - o }'; }

# _kitty_abspath PATH: PATH as an absolute, symlink-resolved path. kitty
# resolves a relative background_image against its own working directory,
# not the shell's, so a relative path would silently show no image.
_kitty_abspath() {
  local p="$1"
  [[ "$p" == /* ]] || p="$PWD/$p"
  if [[ -e "$p" ]]; then
    p="$(cd "$(dirname "$p")" && pwd -P)/$(basename "$p")"
  fi
  printf '%s' "$p"
}

# _kitty_png_for PATH: a PNG kitty can draw for PATH. A .png is used as it
# is; anything else is converted with sips into the nekoshell data dir, once
# per change of the source (a conversion older than the source is redone).
# Only the path goes to stdout, because callers capture it; the warnings go
# to stderr so they reach the screen and not the config.
_kitty_png_for() {
  local src="$1"
  case "$src" in
    *.png | *.PNG)
      printf '%s' "$src"
      return 0
      ;;
  esac
  if [[ ! -e "$src" ]]; then
    log_warn "$src does not exist; kitty needs a PNG, so nothing can be converted yet" >&2
    printf '%s' "$src"
    return 0
  fi
  if [[ ! -e "$KITTY_BACKGROUND_PNG" || "$src" -nt "$KITTY_BACKGROUND_PNG" ]]; then
    run mkdir -p "$(dirname "$KITTY_BACKGROUND_PNG")" >&2
    run sips -s format png "$src" --out "$KITTY_BACKGROUND_PNG" >&2 || {
      log_warn "could not convert $src to PNG; kitty will not draw it" >&2
      printf '%s' "$src"
      return 0
    }
  fi
  printf '%s' "$KITTY_BACKGROUND_PNG"
}

# kitty_render SRC DST FLAVOR: render a template into an owned file. The
# colours go through theme_render_template, so palettes.json stays the only
# place a colour lives; the font, the checkout and the two config paths are
# substituted here, from the functions and constants that define them, so no
# template carries a second copy of any of them. The whole thing is built on
# a temp file beside DST and renamed into place: a failure part way through
# must not leave a half-written config that every new kitty window reads.
kitty_render() {
  local src="$1" dst="$2" flavor="$3" tmp line font patsub=""
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would render $dst ($flavor)"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  tmp="$dst.render"
  theme_render_template "$src" "$tmp" "$flavor" || return 1
  font="$(terminal_font_name)"
  # bash 5.2 expands an & in a replacement to the matched text, and a path
  # may contain one. The option does not exist before 5.2, hence the guard;
  # it is put back afterwards so nothing else in the shell sees the change.
  if shopt -q patsub_replacement 2>/dev/null; then
    patsub=1
    shopt -u patsub_replacement
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//@@FONT@@/$font}"
    line="${line//@@ROOT@@/$NEKOSHELL_ROOT}"
    line="${line//@@PANEL_CONF@@/$KITTY_PANEL_CONF}"
    line="${line//@@KITTY_CONF@@/$KITTY_CONF}"
    printf '%s\n' "$line"
  done <"$tmp" >"$dst.tmp"
  [[ -z "$patsub" ]] || shopt -s patsub_replacement
  rm -f "$tmp"
  mv "$dst.tmp" "$dst"
  log_info "rendered $dst"
}

# kitty_append_background PATH OPACITY: the background image lines, added to
# the end of nekoshell.conf after a render. Appended rather than templated
# because most machines have no background at all, and kitty would refuse a
# blank background_image line. background_opacity is pinned to 1 so the image
# is what shows through the text, not the desktop behind the window.
kitty_append_background() {
  local png tint
  png="$(_kitty_png_for "$1")"
  tint="$(_kitty_tint "$2")"
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would set background_image $png (tint $tint) in $KITTY_NEKOSHELL_CONF"
    return 0
  fi
  cat >>"$KITTY_NEKOSHELL_CONF" <<EOT

# Background image, set by nekoshell terminal background. background_tint is
# 1 - opacity: how much of the background colour is laid over the image.
background_image        $png
background_image_layout scaled
background_tint         $tint
background_opacity      1
EOT
}

# _kitty_backup_conf: a user's kitty.conf goes into the backup set once,
# before the first edit, so uninstall can put the untouched file back.
# backup_path moves the file, so a copy is put straight back for the edit to
# land on. Symlinks are the user's dotfiles setup and files outside $HOME
# cannot be expressed as a backup path; both are edited in place and not
# backed up. Nothing happens without backup.sh, which `nekoshell` always
# loads but a shell that sourced only this adapter may not have.
_kitty_backup_conf() {
  local rel
  [[ -f "$KITTY_CONF" && ! -L "$KITTY_CONF" ]] || return 0
  command -v backup_path >/dev/null 2>&1 || return 0
  case "$KITTY_CONF" in
    "$HOME"/*) rel="${KITTY_CONF#"$HOME"/}" ;;
    *) return 0 ;;
  esac
  [[ -n "${NEKOSHELL_BACKUP_DIR:-}" ]] || backup_begin
  log_info "backing up your $rel before adding the include line"
  backup_path "$rel"
  run cp "$NEKOSHELL_BACKUP_DIR/$rel" "$KITTY_CONF"
}

# kitty_has_include: true when kitty.conf already includes nekoshell.conf.
kitty_has_include() { [[ -f "$KITTY_CONF" ]] && grep -qxF "$KITTY_INCLUDE_LINE" "$KITTY_CONF"; }

# kitty_add_include: the one line nekoshell puts in kitty.conf, appended once
# under its marker. Appended, not prepended: kitty's last value wins, so the
# theme takes effect over whatever the file already sets. kitty.conf is
# created when there is none.
kitty_add_include() {
  if kitty_has_include; then return 0; fi
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would add '$KITTY_INCLUDE_LINE' to $KITTY_CONF"
    return 0
  fi
  _kitty_backup_conf
  mkdir -p "$KITTY_CONFIG_DIR"
  # A file that does not end in a newline would otherwise take the marker
  # onto the end of its last line.
  if [[ -s "$KITTY_CONF" ]] && [[ -n "$(tail -c 1 "$KITTY_CONF")" ]]; then
    printf '\n' >>"$KITTY_CONF"
  fi
  printf '%s\n%s\n' "$KITTY_INCLUDE_MARK" "$KITTY_INCLUDE_LINE" >>"$KITTY_CONF"
  log_ok "added '$KITTY_INCLUDE_LINE' to $KITTY_CONF"
}

# kitty_remove_include: take the include line and its marker back out of
# kitty.conf and leave everything else exactly as it was. A file that is
# empty afterwards was created by nekoshell (or was empty to begin with), so
# it is deleted rather than left as an empty kitty.conf.
kitty_remove_include() {
  local tmp
  kitty_has_include || return 0
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would remove '$KITTY_INCLUDE_LINE' from $KITTY_CONF"
    return 0
  fi
  tmp="$KITTY_CONF.tmp.$$"
  # The marker is only ours when the include follows it: a lone "# nekoshell"
  # elsewhere in the file is the user's comment and stays.
  awk -v mark="$KITTY_INCLUDE_MARK" -v inc="$KITTY_INCLUDE_LINE" '
    {
      if (held) {
        held = 0
        if ($0 == inc) next
        print mark
      }
      if ($0 == mark) { held = 1; next }
      if ($0 == inc) next
      print
    }
    END { if (held) print mark }' "$KITTY_CONF" >"$tmp" && mv "$tmp" "$KITTY_CONF"
  if ! grep -q '[^[:space:]]' "$KITTY_CONF"; then
    rm -f "$KITTY_CONF"
    log_info "removed the now empty $KITTY_CONF"
  else
    log_info "removed '$KITTY_INCLUDE_LINE' from $KITTY_CONF"
  fi
}

# kitty_write_configs FLAVOR [BACKGROUND OPACITY]: the two owned files and
# the include line. The stored background is written again here, because
# nekoshell.conf is rendered from scratch every time and would otherwise
# lose it on the next theme change.
kitty_write_configs() {
  local flavor="$1" bg="${2:-}" opacity="${3:-0.85}"
  kitty_render "$NEKOSHELL_ROOT/terminals/kitty/nekoshell.conf.tmpl" "$KITTY_NEKOSHELL_CONF" "$flavor" || return 1
  [[ -z "$bg" ]] || kitty_append_background "$bg" "$opacity"
  kitty_render "$NEKOSHELL_ROOT/terminals/kitty/nekoshell-panel.conf.tmpl" "$KITTY_PANEL_CONF" "$flavor" || return 1
  kitty_add_include
}

# kitty_reload: ask the kitty this shell runs in to read kitty.conf again, so
# the change shows without a new window. Only possible from inside kitty with
# remote control on, which the first apply cannot yet rely on (kitty reads
# allow_remote_control at startup), so a refusal is a hint, not a failure.
kitty_reload() {
  terminal_detect || return 0
  [[ -n "${KITTY_LISTEN_ON:-}" ]] || {
    log_info "open a new kitty window, or press ctrl+shift+f5 in this one, to see the change"
    return 0
  }
  command -v kitten >/dev/null 2>&1 || return 0
  if ! run_quiet kitten @ --to "$KITTY_LISTEN_ON" load-config 2>/dev/null; then
    log_info "kitty did not reload live; press ctrl+shift+f5 in each window, or open a new one"
  fi
  return 0
}

# terminal_apply FLAVOR: render both files, keep the stored background, put
# the include in place, then try to reload the running kitty.
terminal_apply() {
  local flavor="${1:-mocha}" bg opacity
  bg="$(_kitty_setting background)"
  opacity="$(_kitty_setting background_opacity)"
  [[ -n "$opacity" ]] || opacity="0.85"
  if [[ -n "$bg" ]] && ! _kitty_opacity_ok "$opacity"; then
    log_warn "background_opacity is $opacity, which is not between 0 and 1; using 0.85"
    opacity="0.85"
  fi
  [[ -z "$bg" ]] || bg="$(_kitty_abspath "$bg")"
  kitty_write_configs "$flavor" "$bg" "$opacity" || return 1
  kitty_reload
  return 0
}

# terminal_background PATH|none [OPACITY]: record the choice in nekoshell.toml
# and render it into nekoshell.conf. Recorded first: the render reads the
# same keys on every later theme switch, so the image outlives this call.
terminal_background() {
  local path="${1:-}" opacity="${2:-0.85}" flavor
  [[ -n "$path" ]] || {
    log_fail "usage: nekoshell terminal background PATH|none [OPACITY]"
    return 1
  }
  flavor="$(_kitty_flavor)"
  if [[ "$path" == "none" ]]; then
    _kitty_store background ""
    kitty_write_configs "$flavor" || return 1
  else
    _kitty_opacity_ok "$opacity" || {
      log_fail "opacity must be between 0 and 1"
      return 1
    }
    path="$(_kitty_abspath "$path")"
    [[ -e "$path" ]] || log_warn "$path does not exist yet; writing it into the config anyway"
    _kitty_store background "$path"
    _kitty_store background_opacity "$opacity"
    kitty_write_configs "$flavor" "$path" "$opacity" || return 1
  fi
  kitty_reload
  return 0
}

# terminal_panel CMD...: inside tmux the popup, as everywhere. Inside kitty
# the quick-access terminal, which the kitten shows the first time and
# toggles after that; CMD only matters on the first call, when the panel is
# created around it. Anywhere else there is no kitty to ask, so the default.
terminal_panel() {
  if [[ -n "${TMUX:-}" ]] || ! terminal_detect; then
    terminal_panel_default "$@"
    return $?
  fi
  if [[ ! -f "$KITTY_PANEL_CONF" ]]; then
    log_warn "no $KITTY_PANEL_CONF (run: nekoshell terminal apply); running here"
    "$@"
    return $?
  fi
  if ! command -v kitten >/dev/null 2>&1; then
    log_warn "kitten is not on PATH; running here"
    "$@"
    return $?
  fi
  log_info "alt+m toggles the panel from any kitty window"
  kitten quick-access-terminal --config "$KITTY_PANEL_CONF" "$@"
}

# terminal_remove: the two owned files, the converted background, and the
# include line; nothing else in kitty.conf is touched.
terminal_remove() {
  run rm -f "$KITTY_NEKOSHELL_CONF" "$KITTY_PANEL_CONF" "$KITTY_BACKGROUND_PNG"
  kitty_remove_include
  return 0
}

# _kitty_conf_flavor: the flavour named in nekoshell.conf's header, or nothing.
_kitty_conf_flavor() {
  [[ -f "$KITTY_NEKOSHELL_CONF" ]] || return 0
  sed -n '1s/.*flavour \([a-z]*\).*/\1/p' "$KITTY_NEKOSHELL_CONF"
}

# _kitty_conf_font: the font_family nekoshell.conf sets, or nothing.
_kitty_conf_font() {
  [[ -f "$KITTY_NEKOSHELL_CONF" ]] || return 0
  sed -n 's/^font_family[[:space:]]*//p' "$KITTY_NEKOSHELL_CONF" | head -1
}

terminal_doctor() {
  local want have font
  want="$(_kitty_flavor)"
  have="$(_kitty_conf_flavor)"
  if [[ ! -f "$KITTY_NEKOSHELL_CONF" ]]; then
    report fail "kitty config" "missing (run: nekoshell terminal apply)"
  elif [[ "$have" != "$want" ]]; then
    report fail "kitty config" "rendered for ${have:-an unknown flavour}, theme is $want (run: nekoshell terminal apply)"
  else
    report ok "kitty config" "$KITTY_NEKOSHELL_CONF ($have)"
  fi

  if kitty_has_include; then
    report ok "kitty include" "$KITTY_CONF"
  else
    report fail "kitty include" "'$KITTY_INCLUDE_LINE' missing from $KITTY_CONF (run: nekoshell terminal apply)"
  fi

  font="$(_kitty_conf_font)"
  if [[ "$font" == "$(terminal_font_name)" ]]; then
    report ok "kitty font" "$font"
  elif [[ -z "$font" ]]; then
    report warn "kitty font" "no font to read (see the kitty config row)"
  else
    report fail "kitty font" "$font is not $(terminal_font_name) (run: nekoshell terminal apply)"
  fi

  if [[ -f "$KITTY_PANEL_CONF" ]]; then
    report ok "kitty panel" "$KITTY_PANEL_CONF (alt+m)"
  else
    report fail "kitty panel" "missing (run: nekoshell terminal apply)"
  fi
}
