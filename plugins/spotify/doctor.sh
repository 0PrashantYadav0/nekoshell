#!/usr/bin/env bash
# spotify doctor: the two tools, whether the login has happened, whether the
# user has a client id of their own, and whether theme.toml matches the
# flavour in force.
# shellcheck source=plugins/spotify/lib.sh
source "$PLUGIN_DIR/lib.sh"

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
if [[ -r "$SP_CACHE_DIR/credentials.json" ]]; then
  report ok "spotify login" "$SP_CACHE_DIR/credentials.json"
else
  report warn "spotify login" "run: spotify_player authenticate"
fi

# The shared id is what makes the first quarter-minute empty: Spotify answers
# its start-up requests with 429s. Registering an id is the user's to do (a
# dashboard and a login), so this too is a note with the command, not a
# failure. Only the first characters are shown: the id is not a secret, but
# a row is no place for all 32 of them.
sp_client_id="$(sp_toml_value "$SP_APP_TOML" client_id)"
if [[ -z "$sp_client_id" || "$sp_client_id" == "$SP_SHARED_CLIENT_ID" ]]; then
  report warn "spotify client id" "spotify_player's shared id is rate-limited by Spotify (slow start); run: nekoshell spotify client-id <id> (see plugins/spotify/README.md)"
else
  report ok "spotify client id" "${sp_client_id:0:6}... in $SP_APP_TOML"
fi

# theme.toml is rendered by the theme hook for the flavour in force; one that
# names another flavour, or is missing, means the hook has not run since the
# flavour changed. The name sits inside [[themes]], so it is matched as a
# whole line rather than read with sp_toml_value, which only reads top-level
# keys.
if theme_is_rendered "$SP_THEME_TOML" && grep -qx "name = \"catppuccin_$FLAVOR\"" "$SP_THEME_TOML"; then
  report ok "spotify theme" "catppuccin_$FLAVOR"
else
  report fail "spotify theme" "not rendered for $FLAVOR (run: nekoshell theme $FLAVOR)"
fi

true
