#!/usr/bin/env bash
# spotify uninstall: take back the theme.toml this plugin rendered, and only
# that. app.toml is the user's from the moment it was copied (their client id
# is in it) and stays, as does the cached Spotify login. A theme.toml whose
# header does not name nekoshell was written by the user and is not ours to
# remove.
# shellcheck source=plugins/spotify/lib.sh
source "$PLUGIN_DIR/lib.sh"

if theme_is_rendered "$SP_THEME_TOML"; then
  run rm -f "$SP_THEME_TOML"
fi

true
