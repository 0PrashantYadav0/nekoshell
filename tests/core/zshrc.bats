#!/usr/bin/env bats
load ../helpers
setup() {
  setup_tmp_home
  unset ZDOTDIR TERM_PROGRAM
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
@test "zshrc loads a plugin's late.zsh after plugin.zsh and before local.zsh" {
  echo 'echo local-marker' > "$HOME/.config/nekoshell/zsh/local.zsh"
  run zsh -o NO_GLOBAL_RCS -ic 'exit'
  [ "$status" -eq 0 ]
  assert_contains "$output" "demo-late"
  assert_contains "$output" "local-marker"
  local late_line local_line
  late_line="$(printf '%s\n' "$output" | grep -n '^demo-late$' | head -1 | cut -d: -f1)"
  local_line="$(printf '%s\n' "$output" | grep -n '^local-marker$' | head -1 | cut -d: -f1)"
  [ -n "$late_line" ]
  [ -n "$local_line" ]
  [ "$late_line" -lt "$local_line" ]
}

# `nekoshell terminal apply` downloads iTerm2's shell integration; nothing
# sourced it, so the status bar's directory and git components stayed blank.
@test "zshrc sources the iTerm2 shell integration inside iTerm2" {
  printf 'iterm2_marker() { echo marker; }\n' > "$HOME/.iterm2_shell_integration.zsh"
  export TERM_PROGRAM=iTerm.app
  run zsh -o NO_GLOBAL_RCS -ic 'iterm2_marker'
  [ "$status" -eq 0 ]
  assert_contains "$output" "marker"
}
@test "zshrc leaves the iTerm2 shell integration alone in another terminal" {
  printf 'iterm2_marker() { echo marker; }\n' > "$HOME/.iterm2_shell_integration.zsh"
  run zsh -o NO_GLOBAL_RCS -ic 'if (( $+functions[iterm2_marker] )); then echo LOADED; else echo NOT-LOADED; fi'
  [ "$status" -eq 0 ]
  assert_contains "$output" "NOT-LOADED"
}
@test "zshrc reads a toml written with unusual spacing around the equals sign" {
  printf 'root="%s"\nterminal="fake"\ntheme   =   "mocha"\nplugins=["demo"]\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  run zsh -o NO_GLOBAL_RCS -ic 'echo "plugins=$_nk_plugins"; alias demo'
  assert_contains "$output" "plugins=demo"
  assert_contains "$output" "demo=true"
}
