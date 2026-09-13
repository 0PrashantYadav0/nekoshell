#!/usr/bin/env bats
# The minecraft art provider: a pinned clone, and a greet-art that picks a
# block file itself.
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  unset FAKE_GIT_HAS_COMMIT FAKE_GIT_FAIL_FETCH FAKE_GIT_NOT_REPO NEKOSHELL_SEED MINECRAFT_PACK
  unset CLAUDECODE TMUX NEKOSHELL_PANEL SSH_CONNECTION NEKOSHELL_GREET_MODE NEKOSHELL_GREET_ART
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/minecraft"
  export PLUGIN_DIR="$P" PLUGIN_NAME=minecraft
  MC_DIR="$HOME/.local/share/minecraft-colorscripts"
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

@test "add clones minecraft-colorscripts at the pinned commit" {
  run "$NK" plugin add minecraft
  [ "$status" -eq 0 ]
  assert_contains "$output" "git clone --quiet https://github.com/Axistorm1/minecraft-colorscripts.git $MC_DIR"
  assert_contains "$output" "checkout --quiet e7186dd841a5362df6229dbc16209147ce716a3a"
  assert_not_contains "$output" "ln -sfn"
  [ -f "$MC_DIR/colorscripts/default-1.8.9/stone.txt" ]
  assert_contains "$output" "minecraft enabled"
}

@test "a fetch that fails warns and the add still succeeds" {
  "$NK" plugin add minecraft >/dev/null
  run env FAKE_GIT_FAIL_FETCH=1 "$NK" plugin add minecraft
  [ "$status" -eq 0 ]
  assert_contains "$output" "minecraft: could not fetch minecraft-colorscripts; keeping what is there"
}

@test "greet-art captions the block and prints it" {
  "$NK" plugin add minecraft >/dev/null
  NEKOSHELL_SEED=1 run "$P/greet-art"
  [ "$status" -eq 0 ]
  assert_matches "${lines[0]}" '^(Stone|Oak Planks)$'
  assert_matches "${lines[1]}" '^BLOCK (stone|oak_planks)$'
  [ "${lines[2]}" = "row2" ]
}

@test "greet-art is silent and non-zero before the clone, and with an unknown pack" {
  run "$P/greet-art"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  "$NK" plugin add minecraft >/dev/null
  MINECRAFT_PACK=nothere run "$P/greet-art"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "the greeting draws a block through the provider" {
  "$NK" plugin add minecraft >/dev/null
  run script -q /dev/null "$NK" greet --art minecraft < /dev/null
  assert_contains "$output" "--file-raw - stdin=2"
  grep -qE '^(Stone|Oak Planks)$' "$HOME/.cache/nekoshell/art-name"
}

@test "doctor reports the pack and fails when it is missing" {
  "$NK" plugin add minecraft >/dev/null
  run "$NK" doctor --plugin minecraft
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +minecraft-colorscripts +default-1\.8\.9, 2 blocks'
  rm -rf "$MC_DIR"
  run "$NK" doctor --plugin minecraft
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +minecraft-colorscripts +missing \(nekoshell plugin add minecraft\)'
}
