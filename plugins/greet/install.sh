#!/usr/bin/env bash
# greet install: fetch pokemon-colorscripts, pinned.
#
# It is not in Homebrew, so it is a checkout with a commit written down: the
# sprites are what the greeting draws, and an unpinned copy makes two machines
# installed a month apart show different art. The symlink into ~/.local/bin is
# what puts it on PATH — the zshrc has that directory in front already.

POKEMON_SHA="5802ff67520be2ff6117a0abc78a08501f6252ad"
POKEMON_DIR="$HOME/.local/share/pokemon-colorscripts"
POKEMON_BIN="$HOME/.local/bin/pokemon-colorscripts"
POKEMON_URL="https://gitlab.com/phoneybadger/pokemon-colorscripts.git"

if [[ ! -d "$POKEMON_DIR" ]]; then
  run git clone --quiet "$POKEMON_URL" "$POKEMON_DIR"
else
  # An older copy may not have the pinned commit yet.
  run git -C "$POKEMON_DIR" fetch --quiet
fi
run git -C "$POKEMON_DIR" checkout --quiet "$POKEMON_SHA"
run chmod +x "$POKEMON_DIR/pokemon-colorscripts.py"
run mkdir -p "$HOME/.local/bin"
run ln -sfn "$POKEMON_DIR/pokemon-colorscripts.py" "$POKEMON_BIN"

true
