#!/usr/bin/env bash
# pokemon install: fetch pokemon-colorscripts, pinned.
#
# It is not in Homebrew, so it is a checkout with a commit written down: the
# sprites are what the greeting draws, and an unpinned copy makes two machines
# installed a month apart show different art. The symlink into ~/.local/bin is
# what puts it on PATH — the zshrc has that directory in front already.

POKEMON_SHA="5802ff67520be2ff6117a0abc78a08501f6252ad"
POKEMON_DIR="$HOME/.local/share/pokemon-colorscripts"
POKEMON_BIN="$HOME/.local/bin/pokemon-colorscripts"
POKEMON_URL="https://gitlab.com/phoneybadger/pokemon-colorscripts.git"

# Everything past the first checkout is advisory. Offline, or a directory that
# is not a checkout at all, still leaves a greeting: an older set of sprites is
# a greeting, and no sprites at all is a greeting too (greet-art exits quietly
# when the command is missing, and the stats print on their own). None of it
# is worth aborting `plugin add` over, so each step warns and the hook carries
# on.
if [[ ! -d "$POKEMON_DIR" ]]; then
  run git clone --quiet "$POKEMON_URL" "$POKEMON_DIR"
elif git -C "$POKEMON_DIR" cat-file -e "$POKEMON_SHA^{commit}" 2>/dev/null; then
  : # the pinned commit is already here; nothing to fetch
else
  # An older copy may not have the pinned commit yet.
  run git -C "$POKEMON_DIR" fetch --quiet \
    || log_warn "$PLUGIN_NAME: could not fetch pokemon-colorscripts; keeping what is there"
fi
run git -C "$POKEMON_DIR" checkout --quiet "$POKEMON_SHA" \
  || log_warn "$PLUGIN_NAME: could not check out pokemon-colorscripts at $POKEMON_SHA; keeping what is there"
# Same reasoning: a checkout that never arrived has no script to make
# executable, and the doctor's own row is where that gets reported.
if [[ -f "$POKEMON_DIR/pokemon-colorscripts.py" ]]; then
  run chmod +x "$POKEMON_DIR/pokemon-colorscripts.py"
else
  log_warn "$PLUGIN_NAME: pokemon-colorscripts.py is missing; the greeting will skip the sprite"
fi
run mkdir -p "$HOME/.local/bin"
run ln -sfn "$POKEMON_DIR/pokemon-colorscripts.py" "$POKEMON_BIN"

true
