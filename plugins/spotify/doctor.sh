#!/usr/bin/env bash
# spotify doctor: the two tools, and whether the login has happened.

for sp_tool in spotify_player spotify; do
  if command -v "$sp_tool" >/dev/null 2>&1; then
    report ok "tool: $sp_tool" "$(command -v "$sp_tool")"
  else
    report fail "tool: $sp_tool" "missing (nekoshell plugin add spotify)"
  fi
done

# Logging in opens a browser and asks for a password, which no install can
# finish on its own, so this is a note with the command to run rather than a
# failure. spotify_player writes credentials.json once the login succeeds.
if [[ -r "$HOME/.cache/spotify-player/credentials.json" ]]; then
  report ok "spotify login" "$HOME/.cache/spotify-player/credentials.json"
else
  report warn "spotify login" "run: spotify_player authenticate"
fi

true
