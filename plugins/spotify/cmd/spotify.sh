#!/usr/bin/env bash
# spotify: your own client id, and logging in and out of spotify_player
# shellcheck source=plugins/spotify/lib.sh
source "$PLUGIN_DIR/lib.sh"

usage_spotify() {
  cat <<EOF
usage: nekoshell spotify client-id ID   put your own Spotify client id in app.toml
       nekoshell spotify login          log in to Spotify (again, after a new id)
       nekoshell spotify logout         forget the cached Spotify login

Spotify's rate limit is per application, and spotify_player's built-in id is
shared by everyone who has not registered one, so on it a start-up can wait
12-14 s on 429s. Register an app at $SP_DASHBOARD_URL, give it
the redirect URI $SP_REDIRECT_URI, and hand its Client ID to
client-id. Details: plugins/spotify/README.md.
EOF
}

# _spotify_client_id ID: write `client_id = "ID"` into the user's app.toml,
# replacing the line if there is one. ID has to be 32 hex characters (the
# shape Spotify's dashboard shows) and not spotify_player's own shared id,
# which would change nothing. Status 2 for a malformed id, like a bad flag.
_spotify_client_id() {
  local id="${1:-}"
  [[ $# -eq 1 ]] || {
    usage_spotify >&2
    return 2
  }
  if [[ ! "$id" =~ ^[0-9a-fA-F]{32}$ ]]; then
    log_fail "a client id is 32 hex characters (the Client ID on your app's page at $SP_DASHBOARD_URL); got: $id"
    return 2
  fi
  if [[ "$id" == "$SP_SHARED_CLIENT_ID" ]]; then
    log_fail "that is spotify_player's shared id, the one being rate-limited; register your own at $SP_DASHBOARD_URL"
    return 1
  fi
  [[ -e "$SP_APP_TOML" ]] || {
    log_fail "$SP_APP_TOML is missing; run: nekoshell plugin add spotify"
    return 1
  }
  [[ -L "$SP_APP_TOML" ]] && {
    log_fail "$SP_APP_TOML is a symlink, not a file of your own; run: nekoshell plugin add spotify"
    return 1
  }
  sp_toml_set "$SP_APP_TOML" client_id "$id" || {
    log_fail "could not write $SP_APP_TOML"
    return 1
  }
  log_ok "client_id = \"${id:0:6}...\" in $SP_APP_TOML"
  log_info "now log in through it: nekoshell spotify login"
}

# _spotify_login: forget the cached login and authenticate afresh. The tokens
# are cached per client id, so after a new client_id the old ones would keep
# the shared id in use; spotify_player's own advice is to authenticate again.
_spotify_login() {
  [[ $# -eq 0 ]] || {
    usage_spotify >&2
    return 2
  }
  command -v spotify_player >/dev/null 2>&1 || {
    log_fail "spotify_player is not installed; run: nekoshell plugin add spotify"
    return 1
  }
  sp_forget_login
  log_info "a browser window opens for the Spotify authorisation"
  run spotify_player authenticate
}

# _spotify_logout: remove the cached login, so the next start asks again.
_spotify_logout() {
  [[ $# -eq 0 ]] || {
    usage_spotify >&2
    return 2
  }
  sp_forget_login
  log_ok "logged out; spotify_player asks for the login on its next start"
}

# cmd_spotify SUBCOMMAND ARGS: the dispatcher. No subcommand is a mistake, not
# a request for help: usage goes to stderr with status 2, as for a bad flag.
cmd_spotify() {
  local sub="${1:-}"
  [[ $# -gt 0 ]] && shift
  case "$sub" in
    client-id) _spotify_client_id "$@" ;;
    login) _spotify_login "$@" ;;
    logout) _spotify_logout "$@" ;;
    -h | --help | help)
      usage_spotify
      return 0
      ;;
    *)
      usage_spotify >&2
      return 2
      ;;
  esac
}
