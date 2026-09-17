#!/usr/bin/env bash
# bootstrap.sh: the one-line install.
#
#   curl -fsSL https://raw.githubusercontent.com/0PrashantYadav0/nekoshell/main/bootstrap.sh | bash
#   curl -fsSL .../bootstrap.sh | bash -s -- --yes --profile full --terminal all
#
# Puts a checkout in NEKOSHELL_DIR (default ~/.nekoshell) at NEKOSHELL_REF
# (default main; a tag such as v0.2.0 works), updating one that is already
# there, then hands the flags to install.sh. NEKOSHELL_BOOTSTRAP_DRY_RUN=1
# prints what it would run and stops before install.sh. Homebrew users do not
# need this file: brew install nekoshell, then nekoshell install.
set -euo pipefail

dir="${NEKOSHELL_DIR:-$HOME/.nekoshell}"
ref="${NEKOSHELL_REF:-main}"
repo="${NEKOSHELL_REPO:-https://github.com/0PrashantYadav0/nekoshell.git}"
dry="${NEKOSHELL_BOOTSTRAP_DRY_RUN:-0}"

say() { printf 'nekoshell: %s\n' "$*"; }
run() {
  if [[ "$dry" == 1 ]]; then
    printf 'would: %s\n' "$*"
  else
    "$@"
  fi
}

[[ "$(uname -s)" == "Darwin" ]] || {
  echo "nekoshell supports macOS only" >&2
  exit 1
}
command -v git >/dev/null 2>&1 || {
  echo "git is missing. Install the Xcode Command Line Tools first: xcode-select --install" >&2
  exit 1
}
# shellcheck disable=SC2016  # the install line is printed verbatim, not evaluated
command -v brew >/dev/null 2>&1 || {
  echo 'Homebrew is missing. Install it first:
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' >&2
  exit 1
}

if [[ -d "$dir/.git" ]]; then
  say "updating $dir to $ref"
  run git -C "$dir" fetch --tags origin
  run git -C "$dir" checkout "$ref"
  # A ref that looks like a version tag is not pulled: it is a fixed point,
  # and only a branch such as main has anything new to pull.
  case "$ref" in
    v[0-9]*) : ;;
    *) run git -C "$dir" pull --ff-only ;;
  esac
elif [[ -e "$dir" ]]; then
  echo "$dir exists and is not a git checkout; move it aside or set NEKOSHELL_DIR" >&2
  exit 1
else
  say "cloning $repo ($ref) into $dir"
  # Shallow: the history is 11 MB and growing, the tree it runs from is under
  # 3 MB, and a fresh install only ever needs $ref checked out, not the log.
  # A contributor who wants the history clones it by hand instead (see
  # docs/INSTALL.md); the update path above (fetch --tags, pull --ff-only)
  # still works on a shallow clone. --no-single-branch, though: --depth alone
  # implies --single-branch, which narrows remote.origin.fetch to $ref and
  # leaves nothing for a later `git checkout main` to find, so an install
  # pinned once with NEKOSHELL_REF and later run without it would fail with a
  # "pathspec did not match" error. --no-single-branch keeps every branch tip
  # at depth 1 instead; the tree is what is shared, so the clone stays small.
  run git clone --depth 1 --no-single-branch --branch "$ref" "$repo" "$dir"
fi

say "running install.sh $*"
if [[ "$dry" == 1 ]]; then
  printf 'would: %s\n' "$dir/install.sh $*"
  exit 0
fi
exec "$dir/install.sh" "$@"
