#!/usr/bin/env bats
# bootstrap.sh is the curl | bash entry point: it puts the latest release (or
# a git checkout, for a branch ref) in NEKOSHELL_DIR and hands over to
# install.sh. Every curl and git call goes through a fake, and the dry run
# stops before install.sh so nothing installs.
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_DIR="$HOME/.nekoshell"
  export NEKOSHELL_BOOTSTRAP_DRY_RUN=1
  B="$REPO_ROOT/bootstrap.sh"
  DL="https://github.com/0PrashantYadav0/nekoshell/releases/download"
}
teardown() { teardown_tmp_home; }

# A release the way scripts/package.sh builds one: nekoshell-X.Y.Z/ with
# VERSION and a stub install.sh, as a tarball next to its SHA256SUMS, in a
# directory the fake curl delivers from. Sets FAKE_CURL_SOURCE_DIR and
# FAKE_CURL_LATEST so "latest" resolves to it.
make_release() {
  local version="$1" out="$BATS_TEST_TMPDIR/release-$1"
  mkdir -p "$out/nekoshell-$version"
  echo "$version" >"$out/nekoshell-$version/VERSION"
  # A stub install.sh: bootstrap.sh execs it at the end, and a real one
  # would try to install nekoshell onto this machine.
  printf '#!/bin/sh\nexit 0\n' >"$out/nekoshell-$version/install.sh"
  chmod +x "$out/nekoshell-$version/install.sh"
  tar -czf "$out/nekoshell-$version.tar.gz" -C "$out" "nekoshell-$version"
  (cd "$out" && shasum -a 256 "nekoshell-$version.tar.gz" >SHA256SUMS)
  export FAKE_CURL_SOURCE_DIR="$out"
  export FAKE_CURL_LATEST="https://github.com/0PrashantYadav0/nekoshell/releases/tag/v$version"
}

@test "a fresh machine downloads the latest release into NEKOSHELL_DIR and hands over to install.sh" {
  run "$B" --yes --profile minimal
  [ "$status" -eq 0 ]
  assert_contains "$output" "would: curl -fsSL -o "
  assert_contains "$output" "$DL/v0.2.0/nekoshell-0.2.0.tar.gz"
  assert_contains "$output" "$DL/v0.2.0/SHA256SUMS"
  assert_contains "$output" "would: verify nekoshell-0.2.0.tar.gz against SHA256SUMS"
  assert_contains "$output" "would: mv "
  assert_contains "$output" "would: $HOME/.nekoshell/install.sh --yes --profile minimal"
  assert_not_contains "$output" "git clone"
}

@test "NEKOSHELL_REF picks a release" {
  NEKOSHELL_REF=v0.1.0 run "$B"
  [ "$status" -eq 0 ]
  assert_contains "$output" "$DL/v0.1.0/nekoshell-0.1.0.tar.gz"
  assert_not_contains "$output" "git clone"
}

@test "NEKOSHELL_REF=main clones a checkout instead" {
  NEKOSHELL_REF=main run "$B"
  [ "$status" -eq 0 ]
  assert_contains "$output" "git clone --depth 1 --no-single-branch --branch main https://github.com/0PrashantYadav0/nekoshell.git $HOME/.nekoshell"
  assert_not_contains "$output" "releases/download"
}

@test "an existing checkout is fetched and moved to main, whatever the release" {
  mkdir -p "$HOME/.nekoshell/.git"
  run "$B"
  [ "$status" -eq 0 ]
  assert_contains "$output" "git -C $HOME/.nekoshell fetch --tags origin"
  assert_contains "$output" "git -C $HOME/.nekoshell checkout main"
  assert_contains "$output" "git -C $HOME/.nekoshell pull --ff-only"
  assert_not_contains "$output" "git clone"
  assert_not_contains "$output" "releases/download"
}

@test "a tag ref on an existing checkout checks the tag out with git and does not pull" {
  mkdir -p "$HOME/.nekoshell/.git"
  NEKOSHELL_REF=v0.2.0 run "$B"
  [ "$status" -eq 0 ]
  assert_contains "$output" "checkout v0.2.0"
  assert_not_contains "$output" "pull --ff-only"
  assert_not_contains "$output" "releases/download"
}

@test "an existing release install at the same version is left alone" {
  mkdir -p "$HOME/.nekoshell"
  echo 0.2.0 >"$HOME/.nekoshell/VERSION"; touch "$HOME/.nekoshell/install.sh"
  run "$B"
  [ "$status" -eq 0 ]
  assert_contains "$output" "$HOME/.nekoshell is already v0.2.0"
  assert_not_contains "$output" "releases/download"
  assert_not_contains "$output" "rm -rf"
}

@test "an existing release install at another version is replaced" {
  mkdir -p "$HOME/.nekoshell"
  echo 0.1.0 >"$HOME/.nekoshell/VERSION"; touch "$HOME/.nekoshell/install.sh"
  run "$B"
  [ "$status" -eq 0 ]
  assert_contains "$output" "replacing 0.1.0 in $HOME/.nekoshell with 0.2.0"
  assert_contains "$output" "would: mv $HOME/.nekoshell $HOME/.nekoshell.old."
  assert_contains "$output" "would: mv "
  assert_contains "$output" "would: rm -rf $HOME/.nekoshell.old."
}

@test "a worktree, whose .git is a file, is a checkout too and is never replaced" {
  mkdir -p "$HOME/.nekoshell"
  echo "gitdir: $HOME/repo/.git/worktrees/x" >"$HOME/.nekoshell/.git"
  echo 0.1.0 >"$HOME/.nekoshell/VERSION"; touch "$HOME/.nekoshell/install.sh"
  run "$B"
  [ "$status" -eq 0 ]
  assert_contains "$output" "git -C $HOME/.nekoshell checkout main"
  assert_not_contains "$output" "releases/download"
  assert_not_contains "$output" "rm -rf"
}

@test "a directory that is neither a checkout nor an install is refused" {
  mkdir -p "$HOME/.nekoshell"; touch "$HOME/.nekoshell/file"
  run "$B"
  [ "$status" -eq 1 ]
  assert_contains "$output" "$HOME/.nekoshell exists and is not a nekoshell install"
  NEKOSHELL_REF=main run "$B"
  [ "$status" -eq 1 ]
  assert_contains "$output" "$HOME/.nekoshell exists and is not a git checkout"
}

@test "no release to be found is an error, not a clone" {
  FAKE_CURL_LATEST="https://github.com/0PrashantYadav0/nekoshell/releases" run "$B"
  [ "$status" -eq 1 ]
  assert_contains "$output" "could not find the latest release"
  assert_not_contains "$output" "git clone"
}

@test "not macOS is refused" {
  FAKE_UNAME=Linux run "$B"
  [ "$status" -eq 1 ]
  assert_contains "$output" "macOS only"
}

@test "missing homebrew prints the install line" {
  mkdir -p "$HOME/bin"
  ln -s "$(command -v curl)" "$HOME/bin/curl"; ln -s "$REPO_ROOT/tests/fakes/uname" "$HOME/bin/uname"
  PATH="$HOME/bin:/usr/bin:/bin" run "$B"
  [ "$status" -eq 1 ]
  assert_contains "$output" "Homebrew is missing"
}

@test "a real download is verified, unpacked, and replaced by the next release" {
  make_release 1.0.0
  local target="$HOME/.nekoshell-real"
  NEKOSHELL_DIR="$target" NEKOSHELL_BOOTSTRAP_DRY_RUN=0 run "$B"
  [ "$status" -eq 0 ]
  [ "$(cat "$target/VERSION")" = "1.0.0" ]
  [ -x "$target/install.sh" ]
  [ ! -e "$target/.git" ]

  make_release 1.1.0
  NEKOSHELL_DIR="$target" NEKOSHELL_BOOTSTRAP_DRY_RUN=0 run "$B"
  [ "$status" -eq 0 ]
  assert_contains "$output" "replacing 1.0.0 in $target with 1.1.0"
  [ "$(cat "$target/VERSION")" = "1.1.0" ]
}

@test "the download's temp directory is gone after a real install" {
  # bootstrap.sh ends in exec, which fires no EXIT trap, so the tarball's
  # directory has to be removed before the hand-over rather than by a trap.
  make_release 1.0.0
  local tmpdir="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$tmpdir"
  TMPDIR="$tmpdir" NEKOSHELL_DIR="$HOME/.nekoshell-real" NEKOSHELL_BOOTSTRAP_DRY_RUN=0 run "$B"
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "$tmpdir")" ]
}

@test "a tarball that does not match SHA256SUMS is not unpacked" {
  make_release 1.0.0
  echo "0000000000000000000000000000000000000000000000000000000000000000  nekoshell-1.0.0.tar.gz" >"$FAKE_CURL_SOURCE_DIR/SHA256SUMS"
  local target="$HOME/.nekoshell-real"
  NEKOSHELL_DIR="$target" NEKOSHELL_BOOTSTRAP_DRY_RUN=0 run "$B"
  [ "$status" -eq 1 ]
  assert_contains "$output" "nekoshell-1.0.0.tar.gz does not match SHA256SUMS"
  [ ! -e "$target" ]
}

@test "a real clone stays on main after a pinned tag, and stays shallow" {
  # Regression for --depth without --no-single-branch: that combination
  # narrows remote.origin.fetch to the one ref cloned, so a later `git
  # checkout main` on an existing checkout fails with "pathspec 'main' did
  # not match any file(s) known to git". The fake git only echoes the
  # command line, so it cannot catch that; this test runs the real binary
  # against a real local origin.
  local real_git
  real_git="$(PATH=/usr/bin:/opt/homebrew/bin command -v git)" || skip "no real git on this machine"

  local origin="$BATS_TEST_TMPDIR/origin"
  mkdir -p "$origin"
  (
    cd "$origin" || exit 1
    "$real_git" init -q -b main .
    "$real_git" config user.name "A Person"
    "$real_git" config user.email "a@example.com"
    # A stub install.sh: bootstrap.sh execs it at the end, and a real one
    # would try to install nekoshell onto this machine.
    printf '#!/bin/sh\nexit 0\n' > install.sh
    chmod +x install.sh
    echo one > file
    "$real_git" add -A
    "$real_git" commit -q -s -m "chore: seed"
    "$real_git" tag v1.0.0
    echo two > file
    "$real_git" commit -q -s -am "chore: second commit on main"
    "$real_git" checkout -q -b feature
    echo three > file
    "$real_git" commit -q -s -am "chore: a commit on a branch"
  )

  # Shadow the fake git with the real one, ahead of it on PATH; the fakes for
  # brew and uname (both still needed by bootstrap's preconditions) stay put.
  local realbin; realbin="$BATS_TEST_TMPDIR/realgit"
  mkdir -p "$realbin"
  ln -s "$real_git" "$realbin/git"
  PATH="$realbin:$PATH"
  local target="$HOME/.nekoshell-real"
  # file://, not the plain path: a real remote deep-clones over a protocol,
  # and git silently ignores --depth for a same-machine path clone, which
  # would make this test pass whether or not the fix is in place.
  local repo_url="file://$origin"

  # The first run clones a branch other than main (a tag ref alone would
  # fetch a release tarball now), which is what leaves a later `checkout
  # main` with nothing to find when the clone was --single-branch.
  NEKOSHELL_DIR="$target" NEKOSHELL_REPO="$repo_url" NEKOSHELL_REF=feature NEKOSHELL_BOOTSTRAP_DRY_RUN=0 run "$B"
  [ "$status" -eq 0 ]
  [ -d "$target/.git" ]
  [ "$("$real_git" -C "$target" symbolic-ref --short -q HEAD)" = "feature" ]

  NEKOSHELL_DIR="$target" NEKOSHELL_REPO="$repo_url" NEKOSHELL_REF=v1.0.0 NEKOSHELL_BOOTSTRAP_DRY_RUN=0 run "$B"
  [ "$status" -eq 0 ]
  [ "$("$real_git" -C "$target" describe --tags)" = "v1.0.0" ]

  NEKOSHELL_DIR="$target" NEKOSHELL_REPO="$repo_url" NEKOSHELL_BOOTSTRAP_DRY_RUN=0 run "$B"
  [ "$status" -eq 0 ]
  [ "$("$real_git" -C "$target" symbolic-ref --short -q HEAD)" = "main" ]
  [ "$("$real_git" -C "$target" rev-parse --is-shallow-repository)" = "true" ]
}
