#!/usr/bin/env bats
# The pure plugin: the prompt in place of Starship, colours from the flavour,
# one prompt at a time.
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
  P="$REPO_ROOT/plugins/pure"
  # A fake Homebrew prefix with the two autoload files the formula installs.
  # Autoload files hold the function body, not a definition.
  export HOMEBREW_PREFIX="$HOME/fakebrew"
  mkdir -p "$HOMEBREW_PREFIX/share/zsh/site-functions"
  printf "PROMPT='pure> '\n" > "$HOMEBREW_PREFIX/share/zsh/site-functions/prompt_pure_setup"
  printf ':\n' > "$HOMEBREW_PREFIX/share/zsh/site-functions/async"
}
teardown() { teardown_tmp_home; }

@test "plugin.toml is complete, conflicts with p10k, and the README has its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  grep -q '^conflicts = \["p10k"\]' "$P/plugin.toml"
  grep -q '^conflicts = \["pure"\]' "$REPO_ROOT/plugins/p10k/plugin.toml"
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
}

@test "add installs pure and renders the colours" {
  run "$NK" plugin add pure
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install pure"
  [ -f "$HOME/.config/nekoshell/pure-colors.zsh" ]
  grep -q "zstyle ':prompt:pure:prompt:success' color '#cba6f7'" "$HOME/.config/nekoshell/pure-colors.zsh"
  grep -q "Mocha" "$HOME/.config/nekoshell/pure-colors.zsh"
}

@test "the zshrc lets pure take the prompt and skips starship" {
  "$NK" plugin add pure >/dev/null
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  run zsh -o NO_GLOBAL_RCS -ic 'echo "prompt=$NEKOSHELL_PROMPT"; (( $+functions[starship_precmd] )) && echo STARSHIP-ON; echo "PROMPT=$PROMPT"; zstyle -s ":prompt:pure:path" color c; echo "path=$c"; exit 0'
  [ "$status" -eq 0 ]
  assert_contains "$output" "prompt=pure"
  assert_not_contains "$output" "STARSHIP-ON"
  assert_contains "$output" "PROMPT=pure> "
  assert_contains "$output" "path=#89b4fa"
}

@test "a theme switch re-renders the colours" {
  "$NK" plugin add pure >/dev/null
  run "$NK" theme latte
  [ "$status" -eq 0 ]
  grep -q "zstyle ':prompt:pure:prompt:success' color '#8839ef'" "$HOME/.config/nekoshell/pure-colors.zsh"
  grep -q "Latte" "$HOME/.config/nekoshell/pure-colors.zsh"
}

@test "pure and p10k refuse each other" {
  "$NK" plugin add p10k >/dev/null
  run "$NK" plugin add pure
  [ "$status" -eq 1 ]
  assert_contains "$output" "pure conflicts with p10k; remove it first"
  "$NK" plugin remove p10k >/dev/null
  "$NK" plugin add pure >/dev/null
  run "$NK" plugin add p10k
  [ "$status" -eq 1 ]
  assert_contains "$output" "p10k conflicts with pure; remove it first"
}

@test "doctor reports the prompt function and the colours" {
  "$NK" plugin add pure >/dev/null
  run "$NK" doctor --plugin pure
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +pure prompt +.*prompt_pure_setup'
  assert_matches "$output" 'ok +pure colours +mocha'
  rm "$HOME/.config/nekoshell/pure-colors.zsh"
  run "$NK" doctor --plugin pure
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +pure colours'
}

@test "remove hands the prompt back to starship" {
  "$NK" plugin add pure >/dev/null
  run "$NK" plugin remove pure
  [ "$status" -eq 0 ]
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  run zsh -o NO_GLOBAL_RCS -ic 'echo "prompt=${NEKOSHELL_PROMPT:-starship}"; exit 0'
  assert_contains "$output" "prompt=starship"
}
