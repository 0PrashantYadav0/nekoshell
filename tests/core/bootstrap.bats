#!/usr/bin/env bats
# bootstrap.sh is the curl | bash entry point: it puts a checkout in
# NEKOSHELL_DIR and hands over to install.sh. Every git call goes through the
# fake, and the dry run stops before install.sh so nothing installs.
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_DIR="$HOME/.nekoshell"
  export NEKOSHELL_BOOTSTRAP_DRY_RUN=1
  B="$REPO_ROOT/bootstrap.sh"
}
teardown() { teardown_tmp_home; }

@test "a fresh machine clones main into NEKOSHELL_DIR and hands over to install.sh" {
  run "$B" --yes --profile minimal
  [ "$status" -eq 0 ]
  assert_contains "$output" "git clone --depth 1 --no-single-branch --branch main https://github.com/0PrashantYadav0/nekoshell.git $HOME/.nekoshell"
  assert_contains "$output" "would: $HOME/.nekoshell/install.sh --yes --profile minimal"
}

@test "NEKOSHELL_REF picks a tag" {
  NEKOSHELL_REF=v0.2.0 run "$B"
  [ "$status" -eq 0 ]
  assert_contains "$output" "git clone --depth 1 --no-single-branch --branch v0.2.0"
}

@test "an existing checkout is fetched and moved to the ref" {
  mkdir -p "$HOME/.nekoshell/.git"
  run "$B"
  [ "$status" -eq 0 ]
  assert_contains "$output" "git -C $HOME/.nekoshell fetch --tags origin"
  assert_contains "$output" "git -C $HOME/.nekoshell checkout main"
  assert_contains "$output" "git -C $HOME/.nekoshell pull --ff-only"
  assert_not_contains "$output" "git clone"
}

@test "a tag ref on an existing checkout does not pull" {
  mkdir -p "$HOME/.nekoshell/.git"
  NEKOSHELL_REF=v0.2.0 run "$B"
  [ "$status" -eq 0 ]
  assert_contains "$output" "checkout v0.2.0"
  assert_not_contains "$output" "pull --ff-only"
}

@test "a directory that is not a checkout is refused" {
  mkdir -p "$HOME/.nekoshell"; touch "$HOME/.nekoshell/file"
  run "$B"
  [ "$status" -eq 1 ]
  assert_contains "$output" "$HOME/.nekoshell exists and is not a git checkout"
}

@test "not macOS is refused" {
  FAKE_UNAME=Linux run "$B"
  [ "$status" -eq 1 ]
  assert_contains "$output" "macOS only"
}

@test "missing homebrew prints the install line" {
  mkdir -p "$HOME/bin"
  ln -s "$(command -v git)" "$HOME/bin/git"; ln -s "$REPO_ROOT/tests/fakes/uname" "$HOME/bin/uname"
  PATH="$HOME/bin:/usr/bin:/bin" run "$B"
  [ "$status" -eq 1 ]
  assert_contains "$output" "Homebrew is missing"
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

  NEKOSHELL_DIR="$target" NEKOSHELL_REPO="$repo_url" NEKOSHELL_REF=v1.0.0 NEKOSHELL_BOOTSTRAP_DRY_RUN=0 run "$B"
  [ "$status" -eq 0 ]
  [ -d "$target/.git" ]

  NEKOSHELL_DIR="$target" NEKOSHELL_REPO="$repo_url" NEKOSHELL_BOOTSTRAP_DRY_RUN=0 run "$B"
  [ "$status" -eq 0 ]
  [ "$("$real_git" -C "$target" symbolic-ref --short -q HEAD)" = "main" ]
  [ "$("$real_git" -C "$target" rev-parse --is-shallow-repository)" = "true" ]
}
