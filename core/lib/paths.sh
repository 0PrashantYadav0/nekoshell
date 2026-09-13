#!/usr/bin/env bash
# Well-known paths. Everything is relative to $HOME so tests can redirect it.
# Source this file; do not execute it.

NEKOSHELL_CONFIG="$HOME/.config/nekoshell"
NEKOSHELL_CACHE="$HOME/.cache/nekoshell"
NEKOSHELL_DATA="$HOME/.local/share/nekoshell"
NEKOSHELL_BACKUP_ROOT="$NEKOSHELL_DATA/backup"
export NEKOSHELL_CONFIG NEKOSHELL_CACHE NEKOSHELL_DATA NEKOSHELL_BACKUP_ROOT

NEKOSHELL_TOML="$NEKOSHELL_CONFIG/nekoshell.toml"
export NEKOSHELL_TOML

# nekoshell_root_from PATH: given a path to a file one directory below the
# checkout root (bin/nekoshell, say), print the repo root.
nekoshell_root_from() {
  local p="$1"
  (cd "$(dirname "$(dirname "$p")")" && pwd -P)
}

# NEKOSHELL_ROOT: the checkout. Prefer the recorded root, else derive from this file.
if [[ -z "${NEKOSHELL_ROOT:-}" ]]; then
  if [[ -r "$NEKOSHELL_TOML" ]] && grep -q '^root[[:space:]]*=' "$NEKOSHELL_TOML"; then
    NEKOSHELL_ROOT="$(sed -n 's/^root *= *"\(.*\)"/\1/p' "$NEKOSHELL_TOML" | head -1)"
  elif [[ -r "$NEKOSHELL_CONFIG/root" ]]; then
    NEKOSHELL_ROOT="$(cat "$NEKOSHELL_CONFIG/root")"
  else
    NEKOSHELL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
  fi
fi
export NEKOSHELL_ROOT
