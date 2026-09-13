#!/usr/bin/env bash
# colorscripts install: fetch theamallalgi/colorscripts, pinned.
#
# A checkout with a commit written down, as for the other packs. The pin
# matters more here than elsewhere: these are shell scripts the greeting
# runs, and scripts.txt beside this hook lists the ones that were read and
# timed at this commit. Offline still leaves a greeting.

CS_SHA="7a8779775f922655564db9e518c6c7b5c4956a9a"
CS_DIR="$HOME/.local/share/colorscripts"
CS_URL="https://github.com/theamallalgi/colorscripts.git"

if [[ ! -d "$CS_DIR" ]]; then
  run git clone --quiet "$CS_URL" "$CS_DIR"
elif git -C "$CS_DIR" cat-file -e "$CS_SHA^{commit}" 2>/dev/null; then
  : # the pinned commit is already here; nothing to fetch
else
  run git -C "$CS_DIR" fetch --quiet \
    || log_warn "$PLUGIN_NAME: could not fetch colorscripts; keeping what is there"
fi
run git -C "$CS_DIR" checkout --quiet "$CS_SHA" \
  || log_warn "$PLUGIN_NAME: could not check out colorscripts at $CS_SHA; keeping what is there"
[[ -d "$CS_DIR/colorscripts" ]] || log_warn "$PLUGIN_NAME: the scripts are missing; the greeting will skip them"

true
