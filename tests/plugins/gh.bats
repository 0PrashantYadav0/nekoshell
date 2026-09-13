#!/usr/bin/env bats
# The gh plugin: cached completions, delta as the pager, nothing in $HOME.
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  unset ZDOTDIR FAKE_GH_LOGGED_OUT GH_PAGER
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/gh"
  CACHE="$HOME/.cache/nekoshell/gh-completion.zsh"
}
teardown() { teardown_tmp_home; }

@test "plugin.toml is complete and the README has its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
}

@test "add installs gh and writes nothing into your home" {
  run "$NK" plugin add gh
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install gh"
  [ ! -e "$HOME/.config/gh" ]
}

@test "the shell caches the completion, sources it, and sets GH_PAGER when delta is there" {
  "$NK" plugin add gh >/dev/null
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  run zsh -o NO_GLOBAL_RCS -ic '(( $+functions[_gh] )) && echo GH-COMPLETION; echo "pager=$GH_PAGER"; exit 0'
  [ "$status" -eq 0 ]
  assert_contains "$output" "GH-COMPLETION"
  assert_contains "$output" "pager=delta"
  [ -s "$CACHE" ]
  grep -q '#compdef gh' "$CACHE"
}

@test "a cache newer than the binary is reused, an older one is regenerated" {
  "$NK" plugin add gh >/dev/null
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  echo '_gh() { echo CACHED; }' > "$CACHE"
  touch "$CACHE"
  run zsh -o NO_GLOBAL_RCS -ic '_gh; exit 0'
  assert_contains "$output" "CACHED"
  touch -t 200001010000 "$CACHE"
  run zsh -o NO_GLOBAL_RCS -ic '_gh; exit 0'
  assert_not_contains "$output" "CACHED"
  grep -q '#compdef gh' "$CACHE"
}

@test "without delta GH_PAGER stays unset, and without gh nothing happens" {
  "$NK" plugin add gh >/dev/null
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  mkdir -p "$HOME/bin"
  cp "$REPO_ROOT/tests/fakes/gh" "$HOME/bin/gh"
  run env PATH="$HOME/bin:/usr/bin:/bin" zsh -o NO_GLOBAL_RCS -ic 'echo "pager=${GH_PAGER:-unset}"; exit 0'
  assert_contains "$output" "pager=unset"
  rm -f "$CACHE"
  run env PATH="/usr/bin:/bin" zsh -o NO_GLOBAL_RCS -ic 'echo DONE; exit 0'
  assert_contains "$output" "DONE"
  [ ! -e "$CACHE" ]
}

@test "doctor reports the binary and the login" {
  "$NK" plugin add gh >/dev/null
  run "$NK" doctor --plugin gh
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +tool: gh'
  assert_matches "$output" 'ok +gh auth +logged in'
  FAKE_GH_LOGGED_OUT=1 run "$NK" doctor --plugin gh
  [ "$status" -eq 0 ]
  assert_matches "$output" 'warn +gh auth +not logged in \(run: gh auth login\)'
  run env PATH="/usr/bin:/bin" "$NK" doctor --plugin gh
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +tool: gh'
}
