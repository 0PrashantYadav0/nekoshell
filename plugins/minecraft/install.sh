#!/usr/bin/env bash
# minecraft install: fetch minecraft-colorscripts, pinned.
#
# Not in Homebrew, so a checkout with a commit written down, the way the
# pokemon plugin does it. The launcher script is not used (greet-art picks a
# block file itself), so nothing goes onto PATH. Every step past the first
# clone is advisory: offline still leaves a greeting.

MC_SHA="e7186dd841a5362df6229dbc16209147ce716a3a"
MC_DIR="$HOME/.local/share/minecraft-colorscripts"
MC_URL="https://github.com/Axistorm1/minecraft-colorscripts.git"

if [[ ! -d "$MC_DIR" ]]; then
  run git clone --quiet "$MC_URL" "$MC_DIR"
elif git -C "$MC_DIR" cat-file -e "$MC_SHA^{commit}" 2>/dev/null; then
  : # the pinned commit is already here; nothing to fetch
else
  run git -C "$MC_DIR" fetch --quiet \
    || log_warn "$PLUGIN_NAME: could not fetch minecraft-colorscripts; keeping what is there"
fi
run git -C "$MC_DIR" checkout --quiet "$MC_SHA" \
  || log_warn "$PLUGIN_NAME: could not check out minecraft-colorscripts at $MC_SHA; keeping what is there"
[[ -d "$MC_DIR/colorscripts" ]] || log_warn "$PLUGIN_NAME: the block files are missing; the greeting will skip them"

true
