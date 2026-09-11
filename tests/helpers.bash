#!/usr/bin/env bash
# Shared helpers for bats tests. Every test gets a throwaway HOME.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

# The throwaway HOME lives outside the checkout on purpose. Backups land under
# $HOME, and the installer refuses to write them inside the checkout, so a HOME
# under tests/ would make every install test trip that guard. `pwd -P` because
# macOS temp dirs are reached through symlinks and the installer resolves paths.
NEKOSHELL_TEST_TMP_PREFIX="${TMPDIR:-/tmp}"
export NEKOSHELL_TEST_TMP_PREFIX

setup_tmp_home() {
  HOME="$(cd "$(mktemp -d "${NEKOSHELL_TEST_TMP_PREFIX%/}/nekoshell-home.XXXXXX")" && pwd -P)"
  export HOME
  export XDG_CONFIG_HOME="$HOME/.config"
  mkdir -p "$HOME/.config" "$HOME/.cache" "$HOME/.local/share" "$HOME/.local/bin"
}

teardown_tmp_home() {
  case "${HOME:-}" in
    */nekoshell-home.??????) rm -rf "$HOME" ;;
  esac
}
