#!/usr/bin/env bash
# Shared helpers for bats tests. Every test gets a throwaway HOME.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

setup_tmp_home() {
  mkdir -p "$REPO_ROOT/tests/tmp"
  HOME="$(mktemp -d "$REPO_ROOT/tests/tmp/home.XXXXXX")"
  export HOME
  export XDG_CONFIG_HOME="$HOME/.config"
  mkdir -p "$HOME/.config" "$HOME/.cache" "$HOME/.local/share" "$HOME/.local/bin"
}

teardown_tmp_home() {
  if [[ -n "${HOME:-}" && "$HOME" == "$REPO_ROOT/tests/tmp/"* ]]; then
    rm -rf "$HOME"
  fi
}
