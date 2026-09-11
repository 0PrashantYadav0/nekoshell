#!/usr/bin/env bats
load helpers

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  unset NEKOSHELL_PANEL
}
teardown() { teardown_tmp_home; }

@test "runs spotify_player when credentials are cached" {
  mkdir -p "$HOME/.cache/spotify-player"
  touch "$HOME/.cache/spotify-player/credentials.json"
  run "$REPO_ROOT/bin/nekoshell-music"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "spotify_player " ]
  [ "${lines[1]}" = "PANEL=1" ]
}

@test "authenticates first when no credentials are cached" {
  run "$REPO_ROOT/bin/nekoshell-music"
  [ "$status" -eq 0 ]
  [[ "$output" == *"spotify_player authenticate"* ]]
  [[ "${lines[${#lines[@]}-2]}" == "spotify_player " ]]
}

@test "--remote drives shpotify with single keys" {
  run bash -c "printf 'ns q' | '$REPO_ROOT/bin/nekoshell-music' --remote"
  [ "$status" -eq 0 ]
  [[ "$output" == *"spotify next"* ]]
  [[ "$output" == *"spotify status"* ]]
  [[ "$output" == *"spotify pause"* ]]
}

@test "falls back to the remote when spotify_player is missing" {
  mkdir -p "$HOME/bin"; cp "$REPO_ROOT/tests/fakes/spotify" "$HOME/bin/"
  run bash -c "printf 'q' | PATH='$HOME/bin:/usr/bin:/bin' '$REPO_ROOT/bin/nekoshell-music'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"remote"* ]]
}

@test "spotify_player config selects the mocha theme and the nekoshell device" {
  run python3 -c "
import tomllib
a=tomllib.load(open('$REPO_ROOT/stow/config/.config/spotify-player/app.toml','rb'))
t=tomllib.load(open('$REPO_ROOT/stow/config/.config/spotify-player/theme.toml','rb'))
print(a['theme'], a['enable_media_control'], a['device']['name'], a['device']['volume'], a['device']['bitrate'])
print(t['themes'][0]['name'], t['themes'][0]['palette']['background'])"
  [ "${lines[0]}" = "catppuccin_mocha False nekoshell 70 320" ]
  [ "${lines[1]}" = "catppuccin_mocha #1e1e2e" ]
}
