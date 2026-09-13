#!/usr/bin/env bash
# spotify plugin helpers, shared by its hooks and by `nekoshell spotify`. Both
# run with the core libs loaded (run, log_*, theme_*, backup_*), so this file
# only adds what is particular to spotify_player's own files. Source it from a
# hook or the command with "$PLUGIN_DIR/lib.sh"; do not execute it.
#
# The constants are read by the files that source this one, which shellcheck
# cannot see from here.
# shellcheck disable=SC2034

# The client id spotify_player ships with (ncspot's). Every install that has
# not registered an id of its own presents this one, and Spotify's quota is
# per client id, so it is the id that gets rate-limited at start-up.
SP_SHARED_CLIENT_ID="d420a117a32841c2b3474932e49fb54b"
SP_CONFIG_DIR="$HOME/.config/spotify-player"
SP_APP_TOML="$SP_CONFIG_DIR/app.toml"
SP_THEME_TOML="$SP_CONFIG_DIR/theme.toml"
SP_CACHE_DIR="$HOME/.cache/spotify-player"
SP_DASHBOARD_URL="https://developer.spotify.com/dashboard"
# spotify_player's default login_redirect_uri, which the copied app.toml pins
# and which the Spotify app the user registers has to list.
SP_REDIRECT_URI="http://127.0.0.1:8989/login"

# sp_toml_has FILE KEY: true when FILE has a top-level `KEY = ...` line, i.e.
# one above the first [table]. A key of the same name inside [device] is a
# different key and does not count.
sp_toml_has() {
  [[ -f "$1" ]] || return 1
  [[ "$(awk -v k="$2" '/^\[/ { exit } $0 ~ ("^" k "[[:space:]]*=") { print "yes"; exit }' "$1")" == "yes" ]]
}

# sp_toml_value FILE KEY: what is inside the quotes on that top-level line, or
# nothing when the line or the file is missing.
sp_toml_value() {
  [[ -f "$1" ]] || return 0
  awk -v k="$2" '
    /^\[/ { exit }
    $0 ~ ("^" k "[[:space:]]*=") {
      if (match($0, /"[^"]*"/)) print substr($0, RSTART + 1, RLENGTH - 2)
      exit
    }' "$1"
}

# sp_toml_set FILE KEY VALUE: make FILE's top-level `KEY = ...` line read
# KEY = "VALUE". An existing line is replaced where it is; a missing one is
# added just above the first [table], so it stays top-level (a line appended
# to the end of app.toml would land inside [device]). Nothing else in the file
# changes: the rest is the user's, comments included. The result is built in a
# temp file beside FILE and moved into place through run, so a dry run prints
# the move and leaves FILE alone.
sp_toml_set() {
  local file="$1" key="$2" value="$3" tmp="$1.nekoshell.tmp"
  awk -v k="$key" -v v="$value" '
    BEGIN { line = k " = \"" v "\"" }
    !done && $0 ~ ("^" k "[[:space:]]*=") { print line; done = 1; next }
    !done && /^\[/ { print line; print ""; done = 1 }
    { print }
    END { if (!done) print line }
  ' "$file" >"$tmp" || {
    rm -f "$tmp"
    return 1
  }
  run mv "$tmp" "$file"
  rm -f "$tmp"
}

# sp_forget_login: remove the cached Spotify login: credentials.json (the
# librespot session) and every <client id>_token.json (the Web API tokens),
# each through run. spotify_player asks for the login again on its next start.
sp_forget_login() {
  local f
  for f in "$SP_CACHE_DIR"/credentials.json "$SP_CACHE_DIR"/*_token.json; do
    [[ -e "$f" ]] || continue
    run rm -f "$f"
  done
}
