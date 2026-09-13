#!/usr/bin/env bats
# The omz plugin: three oh-my-zsh pieces through antidote, nothing in $HOME.
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/omz"
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

@test "add puts the git and web-search lines into antidote.txt, remove takes them out" {
  run "$NK" plugin add omz
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "brew install"
  grep -qx 'ohmyzsh/ohmyzsh path:lib/git.zsh' "$HOME/.config/nekoshell/antidote.txt"
  grep -qx 'ohmyzsh/ohmyzsh path:plugins/git' "$HOME/.config/nekoshell/antidote.txt"
  grep -qx 'ohmyzsh/ohmyzsh path:plugins/web-search' "$HOME/.config/nekoshell/antidote.txt"
  # oh-my-zsh's git library must come before its git plugin, which calls its functions.
  [ "$(grep -n 'ohmyzsh' "$HOME/.config/nekoshell/antidote.txt" | head -1 | cut -d: -f2-)" = "ohmyzsh/ohmyzsh path:lib/git.zsh" ]
  run "$NK" plugin remove omz
  [ "$status" -eq 0 ]
  status=0; grep -q 'ohmyzsh' "$HOME/.config/nekoshell/antidote.txt" || status=$?
  [ "$status" -eq 1 ]
}

@test "the plugin writes nothing into the home directory" {
  "$NK" plugin add omz >/dev/null
  [ ! -e "$HOME/.oh-my-zsh" ]
  [ -z "$(find "$HOME" -maxdepth 1 -name '.z*' ! -name '.zsh_sessions')" ]
}
