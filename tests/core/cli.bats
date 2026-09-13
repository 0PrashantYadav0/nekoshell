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

# One machine, several terminals: `use` takes a list, records every one of
# them, and themes each; `apply` and `remove` walk and edit the same list.
@test "terminal use records several terminals, marks them in list, and remove forgets one" {
  run "$NK" terminal use fake,bare
  [ "$status" -eq 0 ]
  grep -q '^terminals = \["fake", "bare"\]' "$HOME/.config/nekoshell/nekoshell.toml"
  grep -q '^terminal = "fake"' "$HOME/.config/nekoshell/nekoshell.toml"
  # bare has no terminal_apply of its own, so use warns about it and carries on.
  assert_contains "$output" "terminal bare: theme not applied"
  grep -q 'fake apply mocha' "$HOME/.cache/nekoshell/hooks.log"
  run "$NK" terminal list
  assert_matches "$output" 'fake +installed \*'
  assert_matches "$output" 'bare +not installed \*'
  run "$NK" terminal remove fake
  [ "$status" -eq 0 ]
  grep -q '^terminals = \["bare"\]' "$HOME/.config/nekoshell/nekoshell.toml"
  grep -q '^terminal = "bare"' "$HOME/.config/nekoshell/nekoshell.toml"
  run "$NK" terminal use all
  grep -q '^terminals = \["bare", "fake"\]' "$HOME/.config/nekoshell/nekoshell.toml"
}
@test "terminal apply re-renders every configured terminal and fails with none" {
  printf 'root = "%s"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  run "$NK" terminal apply
  [ "$status" -eq 1 ]
  assert_contains "$output" "no terminal configured"
  "$NK" terminal use fake >/dev/null
  : > "$HOME/.cache/nekoshell/hooks.log"
  run "$NK" terminal apply
  [ "$status" -eq 0 ]
  grep -q 'fake apply mocha' "$HOME/.cache/nekoshell/hooks.log"
}
@test "terminal background reaches every configured terminal that can draw one" {
  run "$NK" terminal background
  [ "$status" -eq 2 ]
  "$NK" terminal use fake,bare >/dev/null
  : > "$HOME/.cache/nekoshell/hooks.log"
  run "$NK" terminal background /pic.png 0.7
  [ "$status" -eq 0 ]
  grep -q 'fake background /pic.png 0.7' "$HOME/.cache/nekoshell/hooks.log"
  assert_contains "$output" "bare cannot draw a background image; skipped"
}
