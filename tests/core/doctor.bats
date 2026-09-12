#!/usr/bin/env bats
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  mkdir -p "$HOME/.config/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = ["demo"]\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  NK="$REPO_ROOT/bin/nekoshell"
}
teardown() { teardown_tmp_home; }

@test "doctor prints core, terminal and plugin rows and exits 0 with only warns" {
  run "$NK" doctor
  assert_matches "$output" 'ok +homebrew'
  assert_matches "$output" 'ok +zshrc'
  assert_matches "$output" 'ok +fake terminal'
  assert_matches "$output" 'ok +demo +fine'
  assert_matches "$output" 'ok +config'
  [ "$status" -eq 0 ]
}
@test "doctor --json is a JSON array with status, check, detail" {
  run "$NK" doctor --json
  python3 -c "import json,sys; d=json.loads(sys.argv[1]); assert d[0]['status'] in ('ok','warn','fail'); assert 'check' in d[0] and 'detail' in d[0]" "$output"
}
@test "doctor fails when the zshrc is not ours" {
  rm "$HOME/.zshrc"; echo x > "$HOME/.zshrc"
  run "$NK" doctor; [ "$status" -eq 1 ]; assert_matches "$output" 'fail +zshrc'
}
@test "doctor --plugin runs one plugin block only" {
  run "$NK" doctor --plugin demo; assert_matches "$output" 'ok +demo'; assert_not_contains "$output" "homebrew"
}
