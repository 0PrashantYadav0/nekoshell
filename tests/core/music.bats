#!/usr/bin/env bats
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  # The default terminal_panel opens a tmux popup when it is inside tmux and
  # runs the command in this window when it is not. These tests want the
  # second branch, whatever the shell running bats happens to be inside of.
  unset TMUX
  mkdir -p "$HOME/.config/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
}
teardown() { teardown_tmp_home; }

@test "music --here runs the player in this window" {
  "$NK" plugin add fakeplayer >/dev/null
  run "$NK" music --here
  [ "$status" -eq 0 ]
  assert_contains "$output" "fakeplayer running"
}

@test "music without --here goes through the terminal adapter's panel" {
  "$NK" plugin add fakeplayer >/dev/null
  run "$NK" music
  [ "$status" -eq 0 ]
  assert_contains "$output" "fakeplayer running"
}

@test "music picks the first enabled plugin tagged media" {
  "$NK" plugin add demo >/dev/null
  "$NK" plugin add fakeplayer >/dev/null
  run "$NK" music --here
  [ "$status" -eq 0 ]
  assert_contains "$output" "fakeplayer running"
}

@test "music with no media plugin enabled says what to do" {
  "$NK" plugin add demo >/dev/null
  run "$NK" music --here
  [ "$status" -eq 1 ]
  assert_contains "$output" "no media plugin enabled"
  assert_contains "$output" "nekoshell plugin add spotify"
}

@test "music takes the player as an argument" {
  "$NK" plugin add fakeplayer >/dev/null
  run "$NK" music fakeplayer --here
  [ "$status" -eq 0 ]
  assert_contains "$output" "fakeplayer running"
}

@test "music reads music_player from the config" {
  "$NK" plugin add demo >/dev/null
  "$NK" plugin add fakeplayer >/dev/null
  printf 'music_player = "fakeplayer"\n' >> "$HOME/.config/nekoshell/nekoshell.toml"
  run "$NK" music --here
  [ "$status" -eq 0 ]
  assert_contains "$output" "fakeplayer running"
}

@test "music fails clearly when the player has no binary" {
  run "$NK" music guarded --here
  [ "$status" -eq 1 ]
  assert_contains "$output" "nekoshell-guarded"
}
