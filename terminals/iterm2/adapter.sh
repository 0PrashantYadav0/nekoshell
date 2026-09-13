#!/usr/bin/env bash
# iTerm2. Two halves: a dynamic profile file, which iTerm2 re-reads by itself
# whenever it changes, and the global preferences, which live in a plist iTerm2
# rewrites from memory when it quits — so they can only be written while it is
# not running. Everything here is a function or one of the constants below;
# terminals/adapter.sh is sourced first and this file overrides what it supports.

NEKOSHELL_MAIN_GUID="4E4B4F53-4845-4C4C-0001-000000000001"
NEKOSHELL_PANEL_GUID="4E4B4F53-4845-4C4C-0002-000000000002"
# 6 is iTerm2's "Right of screen" window type, the shape the music panel docks in.
NEKOSHELL_PANEL_WINDOW_TYPE="${NEKOSHELL_PANEL_WINDOW_TYPE:-6}"
ITERM_DYNAMIC_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
ITERM_SHELL_INTEGRATION="$HOME/.iterm2_shell_integration.zsh"
export NEKOSHELL_MAIN_GUID NEKOSHELL_PANEL_GUID NEKOSHELL_PANEL_WINDOW_TYPE
export ITERM_DYNAMIC_DIR ITERM_SHELL_INTEGRATION

terminal_name()         { echo "iterm2"; }
terminal_detect()       { [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]]; }
terminal_installed()    { [[ -e "/Applications/iTerm.app" || -e "$HOME/Applications/iTerm.app" ]]; }
terminal_capabilities() { echo "truecolor images background panel hotkey"; }
terminal_font_name()    { echo "JetBrainsMono NF"; }

iterm_is_running() { pgrep -xq iTerm2; }

# _iterm_setting KEY: KEY from nekoshell.toml, or nothing. Tolerates a shell
# where config.sh was never sourced (the adapter is also loadable on its own).
_iterm_setting() {
  local v=""
  command -v config_get >/dev/null 2>&1 && v="$(config_get "$1" 2>/dev/null || true)"
  printf '%s' "$v"
}

# _iterm_flavor: the flavour to render, whatever the caller knows about themes.
_iterm_flavor() {
  local f=""
  command -v theme_current >/dev/null 2>&1 && f="$(theme_current 2>/dev/null || true)"
  [[ -n "$f" ]] || f="$(_iterm_setting theme_resolved)"
  [[ -n "$f" ]] || f="mocha"
  printf '%s' "$f"
}

# _iterm_blend OPACITY: the profile's Blend for a background at OPACITY. They
# are opposites: opacity is how much of the image shows through, Blend is how
# much of the background colour is laid over it.
_iterm_blend() { awk -v o="$1" 'BEGIN { printf "%g\n", 1 - o }'; }

# iterm_write_profiles [FLAVOR] [EXTRA...]: regenerate
# ~/Library/Application Support/iTerm2/DynamicProfiles/nekoshell.json. EXTRA is
# passed to the generator as-is (--background/--blend). The flavour defaults to
# mocha so this stays usable without core/lib/theme.sh.
iterm_write_profiles() {
  local flavor="${1:-mocha}"
  [[ $# -gt 0 ]] && shift
  run mkdir -p "$ITERM_DYNAMIC_DIR"
  # ${1+"$@"} rather than "$@": bash 3.2 treats an empty "$@" as unset under
  # `set -u`, and this function is normally called with no extra arguments.
  run python3 "$NEKOSHELL_ROOT/terminals/iterm2/build-profiles.py" \
    --root "$NEKOSHELL_ROOT" \
    --out "$ITERM_DYNAMIC_DIR/nekoshell.json" \
    --flavor "$flavor" \
    --window-type "$NEKOSHELL_PANEL_WINDOW_TYPE" ${1+"$@"}
}

# Global prefs. Only meaningful when iTerm2 is not running (it rewrites the plist on quit).
iterm_apply_prefs() {
  run defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "$NEKOSHELL_MAIN_GUID"
  run defaults write com.googlecode.iterm2 HideTab -bool true
  run defaults write com.googlecode.iterm2 TerminalMargin -int 16
  run defaults write com.googlecode.iterm2 TerminalVMargin -int 12
  run defaults write com.googlecode.iterm2 PromptOnQuit -bool false
  run defaults write com.googlecode.iterm2 HideScrollbar -bool true
  # Dimming is an application preference, not a profile key: the profile
  # dictionary has no dimming entry, so this is the only place it can be set.
  run defaults write com.googlecode.iterm2 DimInactiveSplitPanes -bool true
  run defaults write com.googlecode.iterm2 SplitPaneDimmingAmount -float 0.3
}

# Exit 0 when the global prefs have not been applied yet.
iterm_prefs_pending() {
  local current
  current="$(defaults read com.googlecode.iterm2 "Default Bookmark Guid" 2>/dev/null || true)"
  [[ "$current" != "$NEKOSHELL_MAIN_GUID" ]]
}

# iterm_install_shell_integration: iTerm2's own zsh hooks. They report the
# working directory and the last command's status, which is what the status
# bar's working directory and git components read. Downloaded rather than
# vendored because it is iTerm2's file and has to match the running iTerm2. A
# failed download is not a failed apply: everything else about the rig works
# without it, so this warns and carries on.
iterm_install_shell_integration() {
  if [[ ! -f "$ITERM_SHELL_INTEGRATION" ]]; then
    run curl -fsSL https://iterm2.com/shell_integration/zsh -o "$ITERM_SHELL_INTEGRATION" \
      || log_warn "iTerm2 shell integration download failed; the status bar's working directory and git components will stay blank"
  fi
  return 0
}

# terminal_apply FLAVOR: profiles, shell integration, global prefs. A stored
# background is written again here, because the profile file is regenerated
# from scratch every time and would otherwise lose it on the next theme change.
terminal_apply() {
  local flavor="${1:-mocha}" bg opacity
  bg="$(_iterm_setting background)"
  if [[ -n "$bg" ]]; then
    opacity="$(_iterm_setting background_opacity)"
    [[ -n "$opacity" ]] || opacity="0.85"
    iterm_write_profiles "$flavor" --background "$bg" --blend "$(_iterm_blend "$opacity")"
  else
    iterm_write_profiles "$flavor"
  fi
  iterm_install_shell_integration
  # Pending prefs are a human step, not a failure: the profiles are already in
  # place and iTerm2 has picked them up.
  if iterm_is_running; then
    log_warn "iTerm2 is running; global preferences not applied. Quit iTerm2 and run: nekoshell terminal apply"
  else
    iterm_apply_prefs
  fi
  return 0
}
