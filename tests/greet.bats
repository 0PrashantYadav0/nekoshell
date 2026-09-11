#!/usr/bin/env bats
load helpers

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export TERM_PROGRAM="iTerm.app"
  unset CLAUDECODE TMUX NEKOSHELL_PANEL SSH_CONNECTION NEKOSHELL_NO_GREET NEKOSHELL_GREET_SSH
  mkdir -p "$HOME/.config/nekoshell/art" "$HOME/.config/fastfetch"
  cp "$REPO_ROOT/stow/config/.config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/"
}
teardown() { teardown_tmp_home; }

greet() {
  local out rc
  out="$(script -q /dev/null "$REPO_ROOT/bin/nekoshell-greet" "$@" < /dev/null)"
  rc=$?
  printf '%s\n' "$out" | sed $'1s/^\^D\b\b//'
  return $rc
}

@test "silent when CLAUDECODE is set" {
  CLAUDECODE=1 run greet
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "silent inside tmux and inside the panel" {
  TMUX=/tmp/x run greet; [ -z "$output" ]
  NEKOSHELL_PANEL=1 run greet; [ -z "$output" ]
}

@test "silent over ssh unless opted in" {
  SSH_CONNECTION="1 2 3 4" run greet; [ -z "$output" ]
  SSH_CONNECTION="1 2 3 4" NEKOSHELL_GREET_SSH=1 NEKOSHELL_SEED=1 run greet
  [[ "$output" == *"fastfetch"* ]]
}

@test "silent when stdout is not a tty" {
  run "$REPO_ROOT/bin/nekoshell-greet"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "pokemon path pipes the sprite into fastfetch and caches the name" {
  NEKOSHELL_SEED=1 run greet
  [ "$status" -eq 0 ]
  [[ "$output" == *"--file-raw - stdin=3"* ]]
  [ "$(cat "$HOME/.cache/nekoshell/art-name")" = "Pikachu · #025 · Electric · Gen 1" ]
}

@test "image path is used when the roll lands above the pokemon share" {
  cp "$REPO_ROOT/art/neko.png" "$HOME/.config/nekoshell/art/"
  echo 'POKEMON_SHARE=0' > "$HOME/.config/nekoshell/greet.conf"
  NEKOSHELL_SEED=1 run greet
  [[ "$output" == *"--iterm $HOME/.config/nekoshell/art/neko.png --logo-width 28 --logo-height 14"* ]]
  [ "$(cat "$HOME/.cache/nekoshell/art-name")" = "neko.png" ]
}

@test "falls back to pokemon when the art pack is empty" {
  echo 'POKEMON_SHARE=0' > "$HOME/.config/nekoshell/greet.conf"
  NEKOSHELL_SEED=1 run greet
  [[ "$output" == *"--file-raw -"* ]]
}

@test "falls back to pokemon outside iTerm2" {
  cp "$REPO_ROOT/art/neko.png" "$HOME/.config/nekoshell/art/"
  echo 'POKEMON_SHARE=0' > "$HOME/.config/nekoshell/greet.conf"
  TERM_PROGRAM=Apple_Terminal NEKOSHELL_SEED=1 run greet
  [[ "$output" == *"--file-raw -"* ]]
}

@test "shiny odds of 1 always passes -s" {
  echo 'SHINY_ODDS=1' > "$HOME/.config/nekoshell/greet.conf"
  NEKOSHELL_SEED=1 run greet
  [ "$(cat "$HOME/.cache/nekoshell/art-name")" = "Pikachu · #025 · Electric · Gen 1 ✦ shiny" ]
}

@test "prints nothing when fastfetch is missing" {
  PATH="$REPO_ROOT/tests/tmp/nothing:/usr/bin:/bin" NEKOSHELL_SEED=1 run greet
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "NEKOSHELL_GREET_TIME prints a millisecond line" {
  NEKOSHELL_GREET_TIME=1 NEKOSHELL_SEED=1 run greet
  last="${lines[${#lines[@]}-1]}"
  last="${last%$'\r'}"
  [[ "$last" =~ ^greet:\ [0-9]+\ ms$ ]]
}

@test "nekoshell-art list and add" {
  run "$REPO_ROOT/bin/nekoshell-art" list
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run "$REPO_ROOT/bin/nekoshell-art" add "$REPO_ROOT/art/ghost.png"
  [ "$status" -eq 0 ]
  run "$REPO_ROOT/bin/nekoshell-art" list
  [ "$output" = "ghost.png" ]
}

@test "sample art files are valid PNGs" {
  for f in neko ghost slime; do
    run python3 -c "d=open('$REPO_ROOT/art/$f.png','rb').read(8); print(d==b'\x89PNG\r\n\x1a\n')"
    [ "$output" = "True" ]
  done
}
