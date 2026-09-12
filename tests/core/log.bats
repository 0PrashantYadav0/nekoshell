#!/usr/bin/env bats
load ../helpers

setup() { setup_tmp_home; }
teardown() { teardown_tmp_home; }

@test "log_ok prints an ok line" {
  run bash -c "source '$REPO_ROOT/core/lib/log.sh'; log_ok 'font installed'"
  [ "$status" -eq 0 ]
  assert_contains "$output" "ok"
  assert_contains "$output" "font installed"
}

@test "log_fail writes to stderr" {
  run bash -c "source '$REPO_ROOT/core/lib/log.sh'; log_fail 'missing brew' 2>&1 >/dev/null"
  assert_contains "$output" "missing brew"
}

@test "log_head prints a blank line then a heading" {
  run bash -c "source '$REPO_ROOT/core/lib/log.sh'; log_head 'demo: A fixture plugin'"
  [ "$status" -eq 0 ]
  assert_contains "$output" "demo: A fixture plugin"
}

@test "run executes the command when not in dry-run" {
  run bash -c "source '$REPO_ROOT/core/lib/log.sh'; run touch '$HOME/made'"
  [ "$status" -eq 0 ]
  [ -f "$HOME/made" ]
}

@test "run prints but does not execute in dry-run" {
  run bash -c "NEKOSHELL_DRY_RUN=1; export NEKOSHELL_DRY_RUN; source '$REPO_ROOT/core/lib/log.sh'; run touch '$HOME/made'"
  [ "$status" -eq 0 ]
  assert_contains "$output" "touch"
  [ ! -f "$HOME/made" ]
}
