#!/usr/bin/env bash
# spotify doctor: the two tools, and whether the login has happened.

# _sp_report_tool LABEL COMMAND: one row, named for what you would install.
_sp_report_tool() {
  if command -v "$2" >/dev/null 2>&1; then
    report ok "tool: $1" "$(command -v "$2")"
  else
    report fail "tool: $1" "missing (nekoshell plugin add spotify)"
  fi
}

_sp_report_tool spotify_player spotify_player
# The formula is called shpotify; the command it installs is called spotify.
# A row that names only one of the two sends you looking for the wrong thing,
# so it names both.
_sp_report_tool "shpotify (spotify)" spotify

# Logging in opens a browser and asks for a password, which no install can
# finish on its own, so this is a note with the command to run rather than a
# failure. spotify_player writes credentials.json once the login succeeds.
if [[ -r "$HOME/.cache/spotify-player/credentials.json" ]]; then
  report ok "spotify login" "$HOME/.cache/spotify-player/credentials.json"
else
  report warn "spotify login" "run: spotify_player authenticate"
fi

true
