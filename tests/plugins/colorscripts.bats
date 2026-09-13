#!/usr/bin/env bats
# The colorscripts art provider: a pinned clone of shell scripts, of which
# only the vetted list is ever run.
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  unset FAKE_GIT_HAS_COMMIT FAKE_GIT_FAIL_FETCH FAKE_GIT_NOT_REPO NEKOSHELL_SEED
  unset CLAUDECODE TMUX NEKOSHELL_PANEL SSH_CONNECTION NEKOSHELL_GREET_MODE NEKOSHELL_GREET_ART
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/colorscripts"
  export PLUGIN_DIR="$P" PLUGIN_NAME=colorscripts
  CS_DIR="$HOME/.local/share/colorscripts"
}
teardown() { teardown_tmp_home; }

@test "plugin.toml is complete, requires greet, and the README has its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  grep -q '^requires_plugins = \["greet"\]' "$P/plugin.toml"
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
  [ -x "$P/greet-art" ]
}

@test "scripts.txt names 32 scripts, one per line, no duplicates" {
  [ "$(grep -c . "$P/scripts.txt")" -eq 32 ]
  [ "$(sort "$P/scripts.txt" | uniq -d | wc -l | tr -d ' ')" -eq 0 ]
  grep -qx bars "$P/scripts.txt"
  grep -qx pacman "$P/scripts.txt"
}

@test "add clones the collection at the pinned commit" {
  run "$NK" plugin add colorscripts
  [ "$status" -eq 0 ]
  assert_contains "$output" "git clone --quiet https://github.com/theamallalgi/colorscripts.git $CS_DIR"
  assert_contains "$output" "checkout --quiet 7a8779775f922655564db9e518c6c7b5c4956a9a"
  [ -x "$CS_DIR/colorscripts/bars" ]
  assert_contains "$output" "colorscripts enabled"
}

@test "greet-art runs only scripts on the vetted list" {
  "$NK" plugin add colorscripts >/dev/null
  local seen="" seed
  for seed in 1 2 3 4 5 6 7 8 9 10; do
    seen="$seen $(NEKOSHELL_SEED=$seed "$P/greet-art" | tr '\n' ' ')"
  done
  assert_contains "$seen" "bars BARS"
  assert_contains "$seen" "pacman PACMAN"
  assert_not_contains "$seen" "notlisted"
  assert_not_contains "$seen" "NOTLISTED"
}

@test "greet-art is silent and non-zero before the clone" {
  run "$P/greet-art"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "the greeting draws a pattern through the provider" {
  "$NK" plugin add colorscripts >/dev/null
  run script -q /dev/null "$NK" greet --art colorscripts < /dev/null
  assert_contains "$output" "--file-raw - stdin=1"
  grep -qE '^(bars|pacman)$' "$HOME/.cache/nekoshell/art-name"
}

@test "doctor counts the vetted scripts that are present" {
  "$NK" plugin add colorscripts >/dev/null
  run "$NK" doctor --plugin colorscripts
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +colorscripts +2 of 32 scripts'
  rm -rf "$CS_DIR"
  run "$NK" doctor --plugin colorscripts
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +colorscripts +missing \(nekoshell plugin add colorscripts\)'
}
