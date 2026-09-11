#!/usr/bin/env bash
# Well-known paths. Everything is relative to $HOME so tests can redirect it.
# Source this file; do not execute it.

NEKOSHELL_CONFIG="$HOME/.config/nekoshell"
NEKOSHELL_CACHE="$HOME/.cache/nekoshell"
NEKOSHELL_DATA="$HOME/.local/share/nekoshell"
NEKOSHELL_BACKUP_ROOT="$NEKOSHELL_DATA/backup"
ITERM_DYNAMIC_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
export NEKOSHELL_CONFIG NEKOSHELL_CACHE NEKOSHELL_DATA NEKOSHELL_BACKUP_ROOT ITERM_DYNAMIC_DIR

# nekoshell_root_from PATH: given a path to a file inside bin/ or lib/, print the repo root.
nekoshell_root_from() {
  local p="$1"
  (cd "$(dirname "$(dirname "$p")")" && pwd -P)
}

# NEKOSHELL_ROOT: the checkout. Prefer the recorded root, else derive from this file.
if [[ -z "${NEKOSHELL_ROOT:-}" ]]; then
  if [[ -r "$NEKOSHELL_CONFIG/root" ]]; then
    NEKOSHELL_ROOT="$(cat "$NEKOSHELL_CONFIG/root")"
  else
    NEKOSHELL_ROOT="$(nekoshell_root_from "${BASH_SOURCE[0]}")"
  fi
fi
export NEKOSHELL_ROOT
