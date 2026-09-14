#!/usr/bin/env bats
# install.sh and uninstall.sh are two-check wrappers: macOS and Homebrew, then
# exec bin/nekoshell. The checks are what a Linux box or a fresh Mac hits
# first, so they get tests of their own. The bin/nekoshell-* shims are the v0.1
# names and must keep delegating.
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export NEKOSHELL_PROFILES_DIR="$HOME/profiles"
  mkdir -p "$NEKOSHELL_PROFILES_DIR"
  echo demo >"$NEKOSHELL_PROFILES_DIR/minimal.txt"
  export NEKOSHELL_SKIP_PREFLIGHT=1 FAKE_TERM=1
}
teardown() { teardown_tmp_home; }

no_brew_path() {
  # A PATH with the fakes but without brew: copy the fakes directory minus brew.
  mkdir -p "$HOME/fakes"
  local f
  for f in "$REPO_ROOT"/tests/fakes/*; do [[ "$(basename "$f")" == brew ]] || ln -s "$f" "$HOME/fakes/"; done
  printf '%s' "$HOME/fakes:/usr/bin:/bin"
}

@test "install.sh refuses a non-mac" {
  FAKE_UNAME=Linux run "$REPO_ROOT/install.sh" --check
  [ "$status" -eq 1 ]
  assert_contains "$output" "macOS only"
}
@test "install.sh without homebrew prints the install line" {
  PATH="$(no_brew_path)" run "$REPO_ROOT/install.sh" --check
  [ "$status" -eq 1 ]
  assert_contains "$output" "Homebrew is missing"
  assert_contains "$output" "raw.githubusercontent.com/Homebrew/install"
}
@test "install.sh hands its flags to nekoshell install" {
  run "$REPO_ROOT/install.sh" --check --profile minimal
  [ "$status" -eq 0 ]
  assert_contains "$output" "would"
  [ ! -e "$HOME/.zshrc" ]
}
@test "uninstall.sh refuses a non-mac and needs homebrew" {
  FAKE_UNAME=Linux run "$REPO_ROOT/uninstall.sh" --yes
  [ "$status" -eq 1 ]
  assert_contains "$output" "macOS only"
  PATH="$(no_brew_path)" run "$REPO_ROOT/uninstall.sh" --yes
  [ "$status" -eq 1 ]
  assert_contains "$output" "Homebrew is missing"
}
@test "uninstall.sh hands over to nekoshell uninstall" {
  "$REPO_ROOT/bin/nekoshell" install --yes --profile minimal >/dev/null
  run "$REPO_ROOT/uninstall.sh" --yes
  [ "$status" -eq 0 ]
  [ ! -L "$HOME/.zshrc" ]
}
@test "every v0.1 shim delegates to the matching subcommand" {
  local shim sub
  for shim in "$REPO_ROOT"/bin/nekoshell-*; do
    sub="${shim##*/nekoshell-}"
    [ -x "$shim" ]
    grep -q "nekoshell\" $sub" "$shim" || grep -q "nekoshell $sub" "$shim"
  done
  run "$REPO_ROOT/bin/nekoshell-doctor" --json
  [ "$status" -ne 2 ]
}
