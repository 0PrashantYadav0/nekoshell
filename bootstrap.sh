#!/usr/bin/env bash
# bootstrap.sh: the one-line install.
#
#   curl -fsSL https://raw.githubusercontent.com/0PrashantYadav0/nekoshell/main/bootstrap.sh | bash
#   curl -fsSL .../bootstrap.sh | bash -s -- --yes --profile full --terminal all
#
# Puts the latest release in NEKOSHELL_DIR (default ~/.nekoshell): the
# tarball a Release attaches, checked against its SHA256SUMS, unpacked, and
# replaced on the next run. NEKOSHELL_REF picks a version (v0.2.0) or, for
# anything that is not a version tag (main), a git checkout of that ref,
# which is what a contributor wants; a directory that is already a git
# checkout is updated with git whatever NEKOSHELL_REF says, so a clone never
# turns into a tarball behind its owner's back. Then hands the flags to
# install.sh. NEKOSHELL_BOOTSTRAP_DRY_RUN=1 prints what it would run and
# stops before install.sh. Homebrew users do not need this file: brew install
# nekoshell, then nekoshell install.
set -euo pipefail

dir="${NEKOSHELL_DIR:-$HOME/.nekoshell}"
ref="${NEKOSHELL_REF:-}"
repo="${NEKOSHELL_REPO:-https://github.com/0PrashantYadav0/nekoshell.git}"
releases="${NEKOSHELL_RELEASES:-https://github.com/0PrashantYadav0/nekoshell/releases}"
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
# shellcheck disable=SC2016  # the install line is printed verbatim, not evaluated
command -v brew >/dev/null 2>&1 || {
  echo 'Homebrew is missing. Install it first:
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' >&2
  exit 1
}

# The latest release's tag, read off the redirect GitHub answers for
# releases/latest. A HEAD request, so the dry run makes it too: the tarball
# it would fetch has the version in its name.
latest_tag() {
  local final
  final="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$releases/latest")" || return 1
  final="${final%/}"
  final="${final##*/}"
  case "$final" in
    v[0-9]*) printf '%s\n' "$final" ;;
    *) return 1 ;;
  esac
}

# --- a git checkout: update it, or make one for a branch ref -----------------
# .git is a file in a worktree or a submodule, so -e rather than -d.
if [[ -e "$dir/.git" || ("$ref" != "" && "$ref" != v[0-9]*) ]]; then
  command -v git >/dev/null 2>&1 || {
    echo "git is missing. Install the Xcode Command Line Tools first: xcode-select --install" >&2
    exit 1
  }
  ref="${ref:-main}"
  if [[ -e "$dir/.git" ]]; then
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
    echo "$dir exists and is not a git checkout; move it aside or set NEKOSHELL_DIR (a release install there updates with NEKOSHELL_REF unset)" >&2
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

# --- a release: the tarball, verified, unpacked in place ----------------------
else
  # A previous run of this path left VERSION and install.sh and no .git; that
  # is the only kind of directory this replaces. Anything else is somebody's.
  if [[ -e "$dir" && ! (-f "$dir/VERSION" && -f "$dir/install.sh") ]]; then
    echo "$dir exists and is not a nekoshell install; move it aside or set NEKOSHELL_DIR" >&2
    exit 1
  fi
  if [[ -z "$ref" ]]; then
    ref="$(latest_tag)" || {
      echo "could not find the latest release at $releases/latest" >&2
      exit 1
    }
  fi
  version="${ref#v}"
  name="nekoshell-$version"
  if [[ -f "$dir/VERSION" && "$(cat "$dir/VERSION")" == "$version" ]]; then
    say "$dir is already $ref"
  else
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/nekoshell-bootstrap.XXXXXX")"
    # For the failure exits below; the exec at the end replaces this process
    # and fires no trap, so the success path removes $tmp by hand first.
    trap 'rm -rf "$tmp"' EXIT
    say "downloading $name.tar.gz from $releases/download/$ref"
    run curl -fsSL -o "$tmp/$name.tar.gz" "$releases/download/$ref/$name.tar.gz"
    run curl -fsSL -o "$tmp/SHA256SUMS" "$releases/download/$ref/SHA256SUMS"
    if [[ "$dry" == 1 ]]; then
      printf 'would: verify %s against SHA256SUMS\n' "$name.tar.gz"
    else
      # The sums file names the tarball as the Release attached it, so pick
      # that line; a mismatch means a broken download or a tampered file,
      # and either way nothing of it is unpacked.
      expected="$(awk -v f="$name.tar.gz" '$2 == f {print $1}' "$tmp/SHA256SUMS")"
      actual="$(shasum -a 256 "$tmp/$name.tar.gz" | awk '{print $1}')"
      [[ -n "$expected" && "$expected" == "$actual" ]] || {
        echo "$name.tar.gz does not match SHA256SUMS; not installing it" >&2
        exit 1
      }
    fi
    run tar -xzf "$tmp/$name.tar.gz" -C "$tmp"
    # The old install moves aside (a sibling, so the same volume and one
    # rename) before the new one moves in, and is dropped last: a failure
    # in between leaves $dir or $dir.old.<pid> intact, never neither.
    old=""
    if [[ -d "$dir" ]]; then
      say "replacing $(cat "$dir/VERSION") in $dir with $version"
      old="$dir.old.$$"
      run mv "$dir" "$old"
    else
      say "unpacking $name into $dir"
    fi
    run mkdir -p "$(dirname "$dir")"
    run mv "$tmp/$name" "$dir"
    [[ -n "$old" ]] && run rm -rf "$old"
    rm -rf "$tmp"
    trap - EXIT
  fi
fi

say "running install.sh $*"
if [[ "$dry" == 1 ]]; then
  printf 'would: %s\n' "$dir/install.sh $*"
  exit 0
fi
exec "$dir/install.sh" "$@"
