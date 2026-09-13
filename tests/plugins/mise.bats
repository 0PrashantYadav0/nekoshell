#!/usr/bin/env bats
# The mise plugin: activation in every shell, a copied-once config, cached completions.
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  unset ZDOTDIR MISE_FAKE_ACTIVATED
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/mise"
}
teardown() { teardown_tmp_home; }

@test "plugin.toml is complete and the README has its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags copy_guard; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
}

@test "add installs mise and copies config.toml once" {
  run "$NK" plugin add mise
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install mise"
  [ -f "$HOME/.config/mise/config.toml" ]
  [ ! -L "$HOME/.config/mise/config.toml" ]
  grep -q '^\[tools\]' "$HOME/.config/mise/config.toml"
}

@test "an existing config.toml is left alone" {
  mkdir -p "$HOME/.config/mise"
  echo '[tools]
node = "22"' > "$HOME/.config/mise/config.toml"
  run "$NK" plugin add mise
  assert_contains "$output" ".config/mise/config.toml exists; left your config alone"
  grep -q 'node = "22"' "$HOME/.config/mise/config.toml"
}

@test "the shell activates mise and caches its completion" {
  "$NK" plugin add mise >/dev/null
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  run zsh -o NO_GLOBAL_RCS -ic 'echo "activated=${MISE_FAKE_ACTIVATED:-no}"; (( $+functions[_mise] )) && echo MISE-COMPLETION; exit 0'
  [ "$status" -eq 0 ]
  assert_contains "$output" "activated=1"
  assert_contains "$output" "MISE-COMPLETION"
  [ -s "$HOME/.cache/nekoshell/mise-completion.zsh" ]
}

@test "without mise the shell starts and nothing is activated" {
  "$NK" plugin add mise >/dev/null
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  run env PATH="/usr/bin:/bin" zsh -o NO_GLOBAL_RCS -ic 'echo "activated=${MISE_FAKE_ACTIVATED:-no}"; exit 0'
  assert_contains "$output" "activated=no"
  assert_not_contains "$output" "command not found"
}

@test "doctor reports the binary and the config" {
  "$NK" plugin add mise >/dev/null
  run "$NK" doctor --plugin mise
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +tool: mise'
  assert_matches "$output" 'ok +mise config'
  rm "$HOME/.config/mise/config.toml"
  run "$NK" doctor --plugin mise
  assert_matches "$output" 'warn +mise config'
}
