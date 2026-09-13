#!/usr/bin/env bash
# Undo install.sh. Everything happens in `nekoshell uninstall`; this file only
# checks that macOS and Homebrew are there and hands over. Flags pass through.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
[[ "$(uname -s)" == "Darwin" ]] || {
  echo "nekoshell supports macOS only" >&2
  exit 1
}
# shellcheck disable=SC2016  # the install line is printed verbatim, not evaluated
command -v brew >/dev/null 2>&1 || {
  echo 'Homebrew is missing. Install it first:
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' >&2
  exit 1
}
exec "$here/bin/nekoshell" uninstall "$@"
