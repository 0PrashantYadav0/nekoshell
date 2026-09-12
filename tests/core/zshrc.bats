#!/usr/bin/env bats
load ../helpers
setup() {
  setup_tmp_home
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  mkdir -p "$HOME/.config/nekoshell/zsh"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = ["demo"]\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  echo 'echo late-marker' > "$HOME/late.zsh"
}
teardown() { teardown_tmp_home; }

@test "zshrc parses the enabled plugins without a subprocess and loads plugin.zsh and bin" {
  run zsh -o NO_GLOBAL_RCS -ic 'echo "plugins=$_nk_plugins"; alias demo; which nekoshell-demo; exit'
  assert_contains "$output" "plugins=demo"
  assert_contains "$output" "demo=true"
  assert_contains "$output" "tests/fixtures/plugins/demo/bin/nekoshell-demo"
}
@test "zshrc puts bin/ on PATH and defines NEKOSHELL_ROOT" {
  run zsh -o NO_GLOBAL_RCS -ic 'echo "$NEKOSHELL_ROOT"; which nekoshell'
  assert_contains "$output" "$REPO_ROOT"
  assert_contains "$output" "$REPO_ROOT/bin/nekoshell"
}
@test "zshrc survives a missing toml" {
  rm "$HOME/.config/nekoshell/nekoshell.toml"
  run zsh -o NO_GLOBAL_RCS -ic 'echo ok'; [ "$status" -eq 0 ]; assert_contains "$output" "ok"
}
