#!/usr/bin/env bats
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  mkdir -p "$HOME/.config/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
}
teardown() { teardown_tmp_home; }

@test "help lists core commands and plugin commands" {
  run "$NK"; [ "$status" -eq 0 ]; assert_contains "$output" "plugin"; assert_contains "$output" "doctor"
  run "$NK" help; [ "$status" -eq 0 ]
  run "$NK" --version; assert_matches "$output" '^nekoshell [0-9]+\.[0-9]+\.[0-9]+$'
}
@test "unknown command exits 2" { run "$NK" bogus; [ "$status" -eq 2 ]; assert_contains "$output" "unknown command: bogus"; }
@test "a plugin command needs its plugin enabled" {
  run "$NK" demo x; [ "$status" -eq 2 ]; assert_contains "$output" "provided by the demo plugin"; assert_contains "$output" "nekoshell plugin add demo"
  "$NK" plugin add demo >/dev/null
  run "$NK" demo x; [ "$status" -eq 0 ]; [ "$output" = "demo cmd x" ]
}
@test "plugin list shows state and summary" {
  run "$NK" plugin list
  assert_matches "$output" 'demo +available +A fixture plugin'
  "$NK" plugin add demo >/dev/null
  run "$NK" plugin list; assert_matches "$output" 'demo +enabled'
  assert_matches "$output" 'kitty-only +unavailable'
}
@test "plugin info prints the toml and README" {
  run "$NK" plugin info demo; assert_contains "$output" 'summary = "A fixture plugin"'
  run "$NK" plugin info nope; [ "$status" -eq 1 ]
}
@test "plugin add and remove round trip through the CLI" {
  run "$NK" plugin add demo needs-demo; [ "$status" -eq 0 ]
  run "$NK" plugin remove needs-demo demo; [ "$status" -eq 0 ]
  [ "$(grep '^plugins' "$HOME/.config/nekoshell/nekoshell.toml")" = 'plugins = []' ]
}
@test "terminal detect, list, use, capabilities" {
  run "$NK" terminal list; assert_contains "$output" "fake"
  run "$NK" terminal use nope; [ "$status" -eq 1 ]
  run "$NK" terminal use fake; [ "$status" -eq 0 ]
  run "$NK" terminal capabilities; [ "$output" = "truecolor images background panel" ]
  TERM_PROGRAM=iTerm.app run "$NK" terminal detect; [ "$output" = "iterm2" ]
}
