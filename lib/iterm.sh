#!/usr/bin/env bash
# iTerm2 integration: dynamic profile file and global preferences.
# Requires lib/log.sh and lib/paths.sh to be sourced first.

NEKOSHELL_MAIN_GUID="4E4B4F53-4845-4C4C-0001-000000000001"
NEKOSHELL_PANEL_GUID="4E4B4F53-4845-4C4C-0002-000000000002"
NEKOSHELL_PANEL_WINDOW_TYPE="${NEKOSHELL_PANEL_WINDOW_TYPE:-6}"
export NEKOSHELL_MAIN_GUID NEKOSHELL_PANEL_GUID NEKOSHELL_PANEL_WINDOW_TYPE

iterm_is_running() { pgrep -xq iTerm2; }

# Generate ~/Library/Application Support/iTerm2/DynamicProfiles/nekoshell.json.
iterm_write_profiles() {
  run mkdir -p "$ITERM_DYNAMIC_DIR"
  run python3 "$NEKOSHELL_ROOT/iterm2/build-profiles.py" \
    --root "$NEKOSHELL_ROOT" \
    --out "$ITERM_DYNAMIC_DIR/nekoshell.json" \
    --window-type "$NEKOSHELL_PANEL_WINDOW_TYPE"
}

# Global prefs. Only meaningful when iTerm2 is not running (it rewrites the plist on quit).
iterm_apply_prefs() {
  run defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "$NEKOSHELL_MAIN_GUID"
  run defaults write com.googlecode.iterm2 HideTab -bool true
  run defaults write com.googlecode.iterm2 TerminalMargin -int 16
  run defaults write com.googlecode.iterm2 TerminalVMargin -int 12
  run defaults write com.googlecode.iterm2 PromptOnQuit -bool false
  run defaults write com.googlecode.iterm2 HideScrollbar -bool true
}

# Exit 0 when the global prefs have not been applied yet.
iterm_prefs_pending() {
  local current
  current="$(defaults read com.googlecode.iterm2 "Default Bookmark Guid" 2>/dev/null || true)"
  [[ "$current" != "$NEKOSHELL_MAIN_GUID" ]]
}
