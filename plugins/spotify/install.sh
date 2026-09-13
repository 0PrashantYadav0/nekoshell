#!/usr/bin/env bash
# spotify install: make app.toml the user's on a machine that ran the earlier
# version, where it was a symlink into the checkout. A link cannot take a
# client_id line without editing the repo, so it goes, and a copy of the
# shipped file lands in its place.
#
# This runs after the core's copy pass, which saw the link, took it for a
# config of the user's and kept it (the copy_guard says as much), so the copy
# is made here rather than left to copy_once. Only a link into this checkout
# is replaced: a real file is the user's own, and a link to somewhere else is
# their dotfiles setup. Both are left exactly as they are.
# shellcheck source=plugins/spotify/lib.sh
source "$PLUGIN_DIR/lib.sh"

if [[ -L "$SP_APP_TOML" ]]; then
  sp_target="$(backup_link_target "$SP_APP_TOML" 2>/dev/null || true)"
  if [[ -n "$sp_target" && "$sp_target" == "$NEKOSHELL_ROOT"/* ]]; then
    log_info "spotify: app.toml was a link into the checkout; making it a file of your own"
    run rm -f "$SP_APP_TOML"
    run cp "$PLUGIN_DIR/files/copy/.config/spotify-player/app.toml" "$SP_APP_TOML"
  fi
fi

true
