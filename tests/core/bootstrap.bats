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
  assert_contains "$output" "git clone --depth 1 --branch main https://github.com/0PrashantYadav0/nekoshell.git $HOME/.nekoshell"
  assert_contains "$output" "would: $HOME/.nekoshell/install.sh --yes --profile minimal"
}

@test "NEKOSHELL_REF picks a tag" {
  NEKOSHELL_REF=v0.2.0 run "$B"
  [ "$status" -eq 0 ]
  assert_contains "$output" "git clone --depth 1 --branch v0.2.0"
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
