#!/usr/bin/env bats
load helpers

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_SKIP_PREFLIGHT=1
  export TERM_PROGRAM=iTerm.app
}
teardown() { teardown_tmp_home; }

@test "doctor fails before install" {
  run "$REPO_ROOT/bin/nekoshell-doctor"
  [ "$status" -ne 0 ]
  [[ "$output" == *"fail"* ]]
}

@test "doctor passes with only warns after a fake install" {
  "$REPO_ROOT/install.sh" --yes >/dev/null
  mkdir -p "$HOME/Library/Fonts"; touch "$HOME/Library/Fonts/JetBrainsMonoNerdFont-Regular.ttf"
  run "$REPO_ROOT/bin/nekoshell-doctor"
  [ "$status" -eq 0 ]
  [[ "$output" != *"fail"* ]]
  [[ "$output" == *"warn"*"spotify"* ]]
}

@test "doctor --json emits an array of checks" {
  "$REPO_ROOT/install.sh" --yes >/dev/null
  run bash -c "'$REPO_ROOT/bin/nekoshell-doctor' --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(type(d).__name__, all(k in d[0] for k in (\"check\",\"status\",\"detail\")))'"
  [ "$output" = "list True" ]
}
