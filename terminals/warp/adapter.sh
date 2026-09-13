#!/usr/bin/env bash
# Warp. Three files under ~/.warp: a custom theme (YAML, watched by Warp and
# picked up within seconds), a tab config (TOML, the music panel: a new window
# running the player, opened through Warp's URI scheme), and settings.toml,
# Warp's own settings file, which it hot-reloads and which the Settings panel
# also writes. settings.toml is the user's, so only three keys in it are
# edited in place (theme, font name, font size), through
# terminals/warp/settings.py, and what they held before is remembered so
# terminal_remove can put it back. terminals/adapter.sh is sourced first and
# this file overrides what it supports.
#
# Observed on Warp 0.2026.09.09: a first launch writes only
# AppAddedAsLoginItem, ExperimentId, NSAutoFillHeuristicControllerEnabled and
# SettingsFileMigrationComplete into the dev.warp.Warp-Stable defaults domain.
# Theme, FontName and FontSize no longer live there; Warp migrated them to
# ~/.warp/settings.toml and its file-locations page now lists the defaults
# domain as legacy. So nothing here touches `defaults`, and Warp does not
# have to be quit for an apply.

WARP_DIR="$HOME/.warp"
WARP_THEMES_DIR="$WARP_DIR/themes"
WARP_TAB_CONFIGS_DIR="$WARP_DIR/tab_configs"
WARP_SETTINGS="$WARP_DIR/settings.toml"
WARP_TAB_CONFIG="$WARP_TAB_CONFIGS_DIR/nekoshell_music.toml"
WARP_BACKGROUND_JPG="$WARP_THEMES_DIR/nekoshell_background.jpg"
# What settings.toml said before the first apply, one `key = value` per line
# in Warp's own TOML spelling, so remove can restore it. Not in nekoshell.toml:
# a custom theme value is an inline table full of double quotes, which the
# flat TOML subset config.sh reads cannot hold.
WARP_PREVIOUS="${NEKOSHELL_CONFIG:-$HOME/.config/nekoshell}/warp-previous.toml"
WARP_FONT_SIZE="15.0"
export WARP_DIR WARP_THEMES_DIR WARP_TAB_CONFIGS_DIR WARP_SETTINGS WARP_TAB_CONFIG
export WARP_BACKGROUND_JPG WARP_PREVIOUS WARP_FONT_SIZE

terminal_name() { echo "warp"; }
terminal_detect() { [[ "${TERM_PROGRAM:-}" == "WarpTerminal" ]]; }
terminal_installed() { [[ -e "/Applications/Warp.app" || -e "$HOME/Applications/Warp.app" ]]; }
# images: Warp's changelog announces both the Kitty and the iTerm image
# protocols on macOS, and the binary carries the Kitty one (transmission
# mediums, unicode placeholders, PNG decoding). background: a custom theme can
# carry a background_image. panel: the tab config opens in a new window.
terminal_capabilities() { echo "truecolor images background panel"; }
# The family name macOS reports for the Nerd Font file (its typographic
# family), which is what Warp's font picker lists.
terminal_font_name() { echo "JetBrainsMono Nerd Font"; }

# _warp_setting KEY: KEY from nekoshell.toml, or nothing. Tolerates a shell
# where config.sh was never sourced (the adapter is also loadable on its own).
_warp_setting() {
  local v=""
  command -v config_get >/dev/null 2>&1 && v="$(config_get "$1" 2>/dev/null || true)"
  printf '%s' "$v"
}

# _warp_flavor: the flavour to render, whatever the caller knows about themes.
_warp_flavor() {
  local f=""
  command -v theme_current >/dev/null 2>&1 && f="$(theme_current 2>/dev/null || true)"
  [[ -n "$f" ]] || f="$(_warp_setting theme_resolved)"
  [[ -n "$f" ]] || f="mocha"
  printf '%s' "$f"
}

# _warp_theme_file FLAVOR: the theme file for FLAVOR. One file per flavour,
# and only the current one is kept, so the picker never lists stale ones.
_warp_theme_file() { printf '%s/nekoshell_%s.yaml' "$WARP_THEMES_DIR" "$1"; }

# _warp_toml_str TEXT: TEXT as a TOML basic string. Only backslash and the
# double quote need escaping in the values written here (paths, font names).
_warp_toml_str() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '"%s"' "$s"
}

# _warp_theme_value FLAVOR: the settings.toml value that selects our theme.
# The shape is Warp's settings schema (ThemeKind -> custom -> CustomTheme with
# name and path), read out of the app bundle's settings_schema.json.
_warp_theme_value() {
  printf '{ custom = { name = %s, path = %s } }' \
    "$(_warp_toml_str "nekoshell $1")" "$(_warp_toml_str "$(_warp_theme_file "$1")")"
}

# _warp_theme_is_ours VALUE: true when a theme value names one of our files.
_warp_theme_is_ours() {
  case "$1" in *"$WARP_THEMES_DIR/nekoshell_"*) return 0 ;; esac
  return 1
}

# _warp_settings_get FILE KEY: what FILE says for KEY, or nothing. Prints the
# right-hand side for a key line; a sub-table form comes back as its lines.
_warp_settings_get() {
  python3 "$NEKOSHELL_ROOT/terminals/warp/settings.py" "$1" get "$2" 2>/dev/null || true
}

# _warp_settings_set FILE KEY VALUE [TAG]: write one key, through run so a
# dry run only prints it.
_warp_settings_set() {
  run python3 "$NEKOSHELL_ROOT/terminals/warp/settings.py" "$1" set "$2" "$3" ${4+"$4"}
}

_warp_settings_unset() {
  run python3 "$NEKOSHELL_ROOT/terminals/warp/settings.py" "$1" unset "$2"
}

# _warp_opacity_ok OPACITY: a decimal from 0 to 1 and nothing else, checked
# before anything is written.
_warp_opacity_ok() { [[ "$1" =~ ^(0|1|0?\.[0-9]+|1\.0+)$ ]]; }

# _warp_opacity_percent OPACITY: Warp wants the theme's opacity as a whole
# number from 0 to 100, not the 0..1 decimal the rest of nekoshell uses.
_warp_opacity_percent() { awk -v o="$1" 'BEGIN { printf "%d\n", o * 100 + 0.5 }'; }

# _warp_abspath PATH: PATH as an absolute path, so the copy below reads the
# file the user meant whatever directory the command ran from.
_warp_abspath() {
  local p="$1"
  [[ "$p" == /* ]] || p="$PWD/$p"
  if [[ -e "$p" ]]; then
    p="$(cd "$(dirname "$p")" && pwd -P)/$(basename "$p")"
  fi
  printf '%s' "$p"
}

# _warp_is_jpg PATH: Warp's theme background only reads .jpg/.jpeg files.
_warp_is_jpg() {
  case "$1" in *.jpg | *.jpeg | *.JPG | *.JPEG | *.Jpg | *.Jpeg) return 0 ;; esac
  return 1
}

# _warp_details FLAVOR: Warp wants to know whether a theme is light or dark
# to pick the shade of its own chrome. Latte is the one light Catppuccin
# flavour; the other three are dark.
_warp_details() {
  case "$1" in latte) echo lighter ;; *) echo darker ;; esac
}

# _warp_remember: before the first edit of settings.toml, keep what the three
# keys said (an absent line means the key was unset) and put the user's file
# into the backup set. backup_path moves the file, so a copy is put straight
# back for the edit to work on; uninstall's restore then moves the original
# over ours. Runs once: the previous-values file is the marker.
_warp_remember() {
  local key v rel
  [[ -f "$WARP_PREVIOUS" ]] && return 0
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would record the current Warp theme and font in $WARP_PREVIOUS"
    return 0
  fi
  mkdir -p "$(dirname "$WARP_PREVIOUS")"
  : >"$WARP_PREVIOUS"
  for key in appearance.themes.theme appearance.text.font_name appearance.text.font_size; do
    v="$(_warp_settings_get "$WARP_SETTINGS" "$key")"
    # A sub-table form spans lines and is not a value; it is restored as
    # nothing, which is the one shape that cannot be misread.
    case "$v" in
      "" | *$'\n'*) continue ;;
    esac
    printf '%s = %s\n' "${key##*.}" "$v" >>"$WARP_PREVIOUS"
  done
  [[ -f "$WARP_SETTINGS" && ! -L "$WARP_SETTINGS" ]] || return 0
  command -v backup_path >/dev/null 2>&1 || return 0
  rel="${WARP_SETTINGS#"$HOME"/}"
  [[ -n "${NEKOSHELL_BACKUP_DIR:-}" ]] || backup_begin
  log_info "backing up your $rel before editing it"
  backup_path "$rel"
  run cp "$NEKOSHELL_BACKUP_DIR/$rel" "$WARP_SETTINGS"
}

# warp_write_theme FLAVOR [OPACITY]: render ~/.warp/themes/nekoshell_FLAVOR.yaml
# from theme.yaml.tmpl, then append what the template cannot carry: `details`,
# which depends on the flavour rather than on a colour, and the background
# image when there is one, at OPACITY (else the stored background_opacity,
# else 0.85). Other flavours' files go, so the theme picker only ever lists
# the flavour in force.
warp_write_theme() {
  local flavor="${1:-mocha}" opacity="${2:-}" dst old percent
  dst="$(_warp_theme_file "$flavor")"
  run mkdir -p "$WARP_THEMES_DIR"
  for old in "$WARP_THEMES_DIR"/nekoshell_*.yaml; do
    if [[ -e "$old" && "$old" != "$dst" ]]; then run rm -f "$old"; fi
  done
  run theme_render_template "$NEKOSHELL_ROOT/terminals/warp/theme.yaml.tmpl" "$dst" "$flavor" || return 1
  [[ -n "$opacity" ]] || opacity="$(_warp_setting background_opacity)"
  [[ -n "$opacity" ]] || opacity="0.85"
  if ! _warp_opacity_ok "$opacity"; then
    log_warn "background_opacity is $opacity, which is not between 0 and 1; using 0.85"
    opacity="0.85"
  fi
  percent="$(_warp_opacity_percent "$opacity")"
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would append details: $(_warp_details "$flavor") to $dst"
    [[ -f "$WARP_BACKGROUND_JPG" ]] && log_info "would append background_image ($percent%) to $dst"
    return 0
  fi
  printf 'details: %s\n' "$(_warp_details "$flavor")" >>"$dst"
  if [[ -f "$WARP_BACKGROUND_JPG" ]]; then
    # The path is relative to the themes directory, per Warp's docs.
    printf 'background_image:\n  path: %s\n  opacity: %s\n' "$(basename "$WARP_BACKGROUND_JPG")" "$percent" >>"$dst"
  fi
  return 0
}

# warp_write_tab_config: the music panel. A tab config is a TOML file Warp
# lists in its + menu and opens through warp://tab_config/<file stem>; this
# one is a single terminal pane that runs the player. The schema (name,
# color, [[panes]] with id/type/commands/is_focused) is the one in Warp's
# bundled tab-configs skill and on its Tab Configs page. Launch
# configurations, the YAML predecessor, are marked legacy in the same docs.
warp_write_tab_config() {
  local cmd
  run mkdir -p "$WARP_TAB_CONFIGS_DIR"
  # The shell runs this line, so the path is single-quoted for the shell and
  # the whole line is a TOML basic string.
  cmd="NEKOSHELL_PANEL=1 '${NEKOSHELL_ROOT//\'/\'\\\'\'}/bin/nekoshell' music --here"
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would write $WARP_TAB_CONFIG"
    return 0
  fi
  cat >"$WARP_TAB_CONFIG.tmp" <<EOF
# nekoshell: the music panel. Written by \`nekoshell terminal apply\`; the next
# apply overwrites this file. Opened with: open "warp://tab_config/nekoshell_music?new_window=true"
name = "nekoshell music"
color = "magenta"

[[panes]]
id = "music"
type = "terminal"
commands = [$(_warp_toml_str "$cmd")]
is_focused = true
EOF
  mv "$WARP_TAB_CONFIG.tmp" "$WARP_TAB_CONFIG"
}

# warp_apply_settings FLAVOR: select the theme and the font in settings.toml.
# Warp re-reads the file within seconds, so this works while it is running.
warp_apply_settings() {
  local flavor="${1:-mocha}"
  _warp_remember
  _warp_settings_set "$WARP_SETTINGS" appearance.themes.theme "$(_warp_theme_value "$flavor")" nekoshell
  _warp_settings_set "$WARP_SETTINGS" appearance.text.font_name "$(_warp_toml_str "$(terminal_font_name)")" nekoshell
  _warp_settings_set "$WARP_SETTINGS" appearance.text.font_size "$WARP_FONT_SIZE" nekoshell
}

# terminal_apply FLAVOR: theme file, tab config, settings. A stored
# background is written again here, because the theme file is rendered from
# scratch every time and would otherwise lose it on the next theme change.
terminal_apply() {
  local flavor="${1:-mocha}" bg
  bg="$(_warp_setting background)"
  if [[ -n "$bg" ]]; then
    bg="$(_warp_abspath "$bg")"
    if ! _warp_is_jpg "$bg"; then
      log_warn "Warp only draws .jpg theme backgrounds; $bg is left out"
    elif [[ -f "$bg" ]]; then
      run mkdir -p "$WARP_THEMES_DIR"
      run cp "$bg" "$WARP_BACKGROUND_JPG"
    else
      log_warn "$bg does not exist; no background for Warp"
    fi
  fi
  warp_write_theme "$flavor" || return 1
  warp_write_tab_config
  warp_apply_settings "$flavor"
  log_info "Warp picks the theme and font up live; a Warp opened before ~/.warp/themes existed may need a restart to see the theme"
  return 0
}

# terminal_background PATH|none [OPACITY]: the theme's background image. Warp
# reads the image from the themes directory and only as JPEG, so the file is
# copied there under a name of ours, and the theme file is rendered again with
# the image and its opacity (0..1 here, a percentage in the file).
terminal_background() {
  local path="${1:-}" opacity="${2:-0.85}"
  [[ -n "$path" ]] || {
    log_fail "usage: nekoshell terminal background PATH|none [OPACITY]"
    return 1
  }
  if [[ "$path" == "none" ]]; then
    run rm -f "$WARP_BACKGROUND_JPG"
    warp_write_theme "$(_warp_flavor)"
    return $?
  fi
  _warp_opacity_ok "$opacity" || {
    log_fail "opacity must be between 0 and 1"
    return 1
  }
  path="$(_warp_abspath "$path")"
  _warp_is_jpg "$path" || {
    log_fail "Warp only draws .jpg backgrounds; convert it first: sips -s format jpeg IMAGE --out IMAGE.jpg"
    return 1
  }
  [[ -f "$path" ]] || {
    log_fail "$path does not exist"
    return 1
  }
  run mkdir -p "$WARP_THEMES_DIR"
  run cp "$path" "$WARP_BACKGROUND_JPG"
  warp_write_theme "$(_warp_flavor)" "$opacity"
}

# terminal_panel CMD...: inside Warp, open the music tab config in a new
# window through the URI scheme; the config runs the player itself, so CMD is
# not needed there. Inside tmux the popup is the panel; anywhere else the
# command runs here.
terminal_panel() {
  if [[ -n "${TMUX:-}" || "${TERM_PROGRAM:-}" != "WarpTerminal" ]]; then
    terminal_panel_default "$@"
    return $?
  fi
  if [[ ! -f "$WARP_TAB_CONFIG" ]]; then
    log_warn "$WARP_TAB_CONFIG is missing (run: nekoshell terminal apply); running here"
    "$@"
    return $?
  fi
  run open "warp://tab_config/nekoshell_music?new_window=true"
}

# _warp_restore KEY OURS: put back what settings.toml said for KEY before the
# first apply, but only while the key still holds OURS; a value the user
# changed since is theirs and stays.
_warp_restore() {
  local key="$1" ours="$2" cur prev
  cur="$(_warp_settings_get "$WARP_SETTINGS" "$key")"
  [[ -n "$cur" ]] || return 0
  [[ "$cur" == "$ours" ]] || return 0
  prev="$(_warp_settings_get "$WARP_PREVIOUS" "${key##*.}")"
  if [[ -n "$prev" ]]; then
    _warp_settings_set "$WARP_SETTINGS" "$key" "$prev"
  else
    _warp_settings_unset "$WARP_SETTINGS" "$key"
  fi
}

# terminal_remove: delete the owned files and hand settings.toml back. The
# theme selection is restored whenever it still names one of our files, the
# font only while it is still ours.
terminal_remove() {
  local cur prev
  run rm -f "$WARP_THEMES_DIR"/nekoshell_*.yaml "$WARP_BACKGROUND_JPG" "$WARP_TAB_CONFIG"
  cur="$(_warp_settings_get "$WARP_SETTINGS" appearance.themes.theme)"
  if _warp_theme_is_ours "$cur"; then
    prev="$(_warp_settings_get "$WARP_PREVIOUS" theme)"
    if [[ -n "$prev" ]]; then
      _warp_settings_set "$WARP_SETTINGS" appearance.themes.theme "$prev"
    else
      _warp_settings_unset "$WARP_SETTINGS" appearance.themes.theme
    fi
  fi
  _warp_restore appearance.text.font_name "$(_warp_toml_str "$(terminal_font_name)")"
  _warp_restore appearance.text.font_size "$WARP_FONT_SIZE"
  run rm -f "$WARP_PREVIOUS"
  return 0
}

terminal_doctor() {
  local flavor file cur font head=""
  flavor="$(_warp_flavor)"
  file="$(_warp_theme_file "$flavor")"
  # Read into a variable rather than piped into grep -q, which leaves early
  # and turns a match into a SIGPIPE on head under `set -o pipefail`.
  [[ -f "$file" ]] && head="$(head -n 3 "$file" 2>/dev/null || true)"
  if [[ "$head" == *nekoshell* ]]; then
    report ok "warp theme" "$file"
  else
    report fail "warp theme" "missing for $flavor (run: nekoshell terminal apply)"
  fi

  cur="$(_warp_settings_get "$WARP_SETTINGS" appearance.themes.theme)"
  case "$cur" in
    *"$file"*) report ok "warp settings" "theme is nekoshell $flavor" ;;
    "") report fail "warp settings" "no theme selected in $WARP_SETTINGS (run: nekoshell terminal apply)" ;;
    *) report fail "warp settings" "theme is not nekoshell $flavor (run: nekoshell terminal apply)" ;;
  esac

  font="$(_warp_settings_get "$WARP_SETTINGS" appearance.text.font_name)"
  if [[ "$font" == "$(_warp_toml_str "$(terminal_font_name)")" ]]; then
    report ok "warp font" "$(terminal_font_name) $WARP_FONT_SIZE"
  elif [[ -z "$font" ]]; then
    report fail "warp font" "no font_name in $WARP_SETTINGS (run: nekoshell terminal apply)"
  else
    report fail "warp font" "$font is not $(terminal_font_name) (run: nekoshell terminal apply)"
  fi

  if [[ -f "$WARP_TAB_CONFIG" ]]; then
    report ok "warp panel" "$WARP_TAB_CONFIG"
  else
    report fail "warp panel" "missing (run: nekoshell terminal apply)"
  fi
}
