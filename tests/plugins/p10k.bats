#!/usr/bin/env bats
# The p10k plugin: Powerlevel10k in place of Starship, a config that is the
# user's once copied, and colours that follow the flavour.
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  unset ZDOTDIR
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/p10k"
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

@test "add installs powerlevel10k, copies the config once and renders the colours" {
  run "$NK" plugin add p10k
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install powerlevel10k"
  [ -f "$HOME/.p10k.zsh" ]
  [ ! -L "$HOME/.p10k.zsh" ]
  grep -q 'NEKOSHELL_P10K_MAGENTA' "$HOME/.p10k.zsh"
  grep -q 'POWERLEVEL9K_INSTANT_PROMPT=${NEKOSHELL_P10K_INSTANT_PROMPT:-verbose}' "$HOME/.p10k.zsh"
  [ -f "$HOME/.config/nekoshell/p10k-colors.zsh" ]
  grep -q "^export NEKOSHELL_P10K_MAGENTA='#f5c2e7'" "$HOME/.config/nekoshell/p10k-colors.zsh"
  grep -q "Mocha" "$HOME/.config/nekoshell/p10k-colors.zsh"
}

@test "an existing ~/.p10k.zsh is left alone" {
  echo 'mine' > "$HOME/.p10k.zsh"
  run "$NK" plugin add p10k
  [ "$status" -eq 0 ]
  assert_contains "$output" ".p10k.zsh exists; left your config alone"
  [ "$(cat "$HOME/.p10k.zsh")" = "mine" ]
}

@test "a theme switch re-renders the colours" {
  "$NK" plugin add p10k >/dev/null
  run "$NK" theme latte
  [ "$status" -eq 0 ]
  grep -q "^export NEKOSHELL_P10K_MAGENTA='#ea76cb'" "$HOME/.config/nekoshell/p10k-colors.zsh"
  grep -q "Latte" "$HOME/.config/nekoshell/p10k-colors.zsh"
}

# The core zshrc hands the prompt to the plugin: NEKOSHELL_PROMPT is set and
# Starship is not started. A Starship that is on PATH must still not be
# initialised, which is what the function check proves on a machine that has
# it (the fakes dir carries a starship stand-in that prints nothing usable).
@test "the zshrc lets p10k take the prompt and skips starship" {
  "$NK" plugin add p10k >/dev/null
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  run zsh -o NO_GLOBAL_RCS -ic 'echo "prompt=$NEKOSHELL_PROMPT"; (( $+functions[starship_precmd] )) && echo STARSHIP-ON; echo "grey=$NEKOSHELL_P10K_GREY"; exit 0'
  [ "$status" -eq 0 ]
  assert_contains "$output" "prompt=p10k"
  assert_not_contains "$output" "STARSHIP-ON"
  assert_contains "$output" "grey=#7f849c"
}

@test "early.zsh switches instant prompt off when greet is enabled" {
  "$NK" plugin add p10k >/dev/null
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  run zsh -o NO_GLOBAL_RCS -ic 'echo "ip=${NEKOSHELL_P10K_INSTANT_PROMPT:-unset}"; exit 0'
  assert_contains "$output" "ip=unset"
  sed -i '' 's/^plugins = \["p10k"\]/plugins = ["greet", "p10k"]/' "$HOME/.config/nekoshell/nekoshell.toml"
  run zsh -o NO_GLOBAL_RCS -ic 'echo "ip=${NEKOSHELL_P10K_INSTANT_PROMPT:-unset}"; exit 0'
  assert_contains "$output" "ip=off"
}

@test "doctor reports the theme, the config and the colours" {
  "$NK" plugin add p10k >/dev/null
  run "$NK" doctor --plugin p10k
  assert_matches "$output" '(ok|fail) +p10k theme'
  assert_matches "$output" 'ok +p10k config +.*\.p10k\.zsh'
  assert_matches "$output" 'ok +p10k colours +mocha'
  rm "$HOME/.config/nekoshell/p10k-colors.zsh"
  run "$NK" doctor --plugin p10k
  assert_matches "$output" 'fail +p10k colours'
}

@test "remove drops the plugin and starship takes the prompt back" {
  "$NK" plugin add p10k >/dev/null
  run "$NK" plugin remove p10k
  [ "$status" -eq 0 ]
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  run zsh -o NO_GLOBAL_RCS -ic 'echo "prompt=${NEKOSHELL_PROMPT:-starship}"; exit 0'
  assert_contains "$output" "prompt=starship"
  [ -f "$HOME/.p10k.zsh" ]
}
