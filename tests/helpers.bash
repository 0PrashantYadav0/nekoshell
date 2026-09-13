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
  # Captured before a test's own setup() puts tests/fakes in front of PATH, so
  # real_git below always reaches the real git rather than the fake that just
  # echoes its argv.
  NEKOSHELL_REAL_PATH="$PATH"
  export NEKOSHELL_REAL_PATH
}

# real_git ARGS...: git from the real PATH, bypassing tests/fakes/git (which
# only echoes its argv and never touches the filesystem). Tests use this to
# inspect the checkout itself, e.g. to prove a copy never wrote into $REPO_ROOT.
real_git() {
  PATH="$NEKOSHELL_REAL_PATH" git "$@"
}

teardown_tmp_home() {
  case "${HOME:-}" in
    */nekoshell-home.??????) rm -rf "$HOME" ;;
  esac
}

# relpath TARGET FROM_DIR: TARGET as a path relative to FROM_DIR, the shape stow
# writes its links in.
relpath() {
  python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$1" "$2"
}

# Assertions.
#
# bats 1.14: a failing `[[ ]]` that is not a test's last statement does not fail
# the test, because a compound command's status does not reach the ERR trap bats
# installs. `[ ]` and ordinary commands do. These are plain functions, so their
# non-zero return stops the test, and they print what they expected next to what
# they got instead of leaving a bare line number.
assert_contains() {
  case "$1" in *"$2"*) return 0;; esac
  echo "expected to contain: $2" >&2
  echo "actual: $1" >&2
  return 1
}

assert_not_contains() {
  case "$1" in
    *"$2"*)
      echo "expected NOT to contain: $2" >&2
      echo "actual: $1" >&2
      return 1
      ;;
  esac
  return 0
}

assert_matches() {
  if [[ "$1" =~ $2 ]]; then return 0; fi
  echo "expected to match: $2" >&2
  echo "actual: $1" >&2
  return 1
}
