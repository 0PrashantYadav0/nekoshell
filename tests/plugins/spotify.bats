#!/usr/bin/env bats
load ../helpers

# The Spotify player. spotify_player streams on its own (Premium); shpotify
# drives the desktop app over AppleScript and is the fallback. The plugin is
# tagged `media`, which is what `nekoshell music` looks for.

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  # The launcher prepends a Homebrew prefix to PATH. Point it somewhere empty
  # so the tests can never reach a real spotify_player on the developer's Mac.
  export NEKOSHELL_BREW_PREFIX="$HOME/fakebrew"
  unset NEKOSHELL_PANEL
  unset TMUX
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/spotify"
  PLAYER="$P/bin/nekoshell-spotify"
}
teardown() { teardown_tmp_home; }

@test "plugin.toml is complete and the README has its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  grep -q '^requires *= *\["spotify_player", "shpotify"\]$' "$P/plugin.toml"
  grep -q '^tags *= *\["media"\]$' "$P/plugin.toml"
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
  grep -qF "authenticate" "$P/README.md"
}

@test "add installs both tools and links the spotify-player config" {
  run "$NK" plugin add spotify
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install spotify_player shpotify"
  [ -L "$HOME/.config/spotify-player/app.toml" ]
  [ -L "$HOME/.config/spotify-player/theme.toml" ]
}

@test "remove unlinks the config" {
  "$NK" plugin add spotify >/dev/null
  run "$NK" plugin remove spotify
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.config/spotify-player/app.toml" ]
  [ "$(grep '^plugins' "$HOME/.config/nekoshell/nekoshell.toml")" = 'plugins = []' ]
}

@test "the player runs spotify_player when credentials are cached" {
  mkdir -p "$HOME/.cache/spotify-player"
  touch "$HOME/.cache/spotify-player/credentials.json"
  run "$PLAYER"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "spotify_player " ]
  [ "${lines[1]}" = "PANEL=1" ]
}

@test "the player authenticates first when no credentials are cached" {
  run "$PLAYER"
  [ "$status" -eq 0 ]
  assert_contains "$output" "spotify_player authenticate"
  [ "${lines[${#lines[@]}-2]}" = "spotify_player " ]
}

@test "--remote drives shpotify with single keys" {
  run bash -c "printf 'ns q' | '$PLAYER' --remote"
  [ "$status" -eq 0 ]
  assert_contains "$output" "spotify next"
  assert_contains "$output" "spotify status"
  assert_contains "$output" "spotify pause"
}

@test "--remote survives a failing shpotify command" {
  mkdir -p "$HOME/bin"
  cat > "$HOME/bin/spotify" <<'EOF'
#!/usr/bin/env bash
echo "spotify $*"
[ "$1" = "next" ] && exit 1
exit 0
EOF
  chmod +x "$HOME/bin/spotify"
  run bash -c "printf 'nsq' | PATH='$HOME/bin:$PATH' '$PLAYER' --remote"
  [ "$status" -eq 0 ]
  assert_contains "$output" "spotify next"
  assert_contains "$output" "spotify status"
}

@test "falls back to the remote when spotify_player is missing" {
  mkdir -p "$HOME/bin"; cp "$REPO_ROOT/tests/fakes/spotify" "$HOME/bin/"
  run bash -c "printf 'q' | PATH='$HOME/bin:/usr/bin:/bin' '$PLAYER'"
  [ "$status" -eq 0 ]
  assert_contains "$output" "remote"
}

@test "the spotify_player config selects the mocha theme and the nekoshell device" {
  run python3 -c "
import tomllib
a=tomllib.load(open('$P/files/link/.config/spotify-player/app.toml','rb'))
t=tomllib.load(open('$P/files/link/.config/spotify-player/theme.toml','rb'))
print(a['theme'], a['enable_media_control'], a['device']['name'], a['device']['volume'], a['device']['bitrate'])
print(t['themes'][0]['name'], t['themes'][0]['palette']['background'])"
  [ "${lines[0]}" = "catppuccin_mocha False nekoshell 70 320" ]
  [ "${lines[1]}" = "catppuccin_mocha #1e1e2e" ]
}

# A terminal panel runs a profile's command without a login shell, so it starts
# with launchd's PATH and nothing from Homebrew on it. The launcher has to put
# the prefixes back itself or it always reports spotify_player missing.
@test "the panel finds spotify_player with only launchd's PATH" {
  mkdir -p "$HOME/fakebrew/bin" "$HOME/.cache/spotify-player"
  cp "$REPO_ROOT/tests/fakes/spotify_player" "$HOME/fakebrew/bin/spotify_player"
  touch "$HOME/.cache/spotify-player/credentials.json"
  run env NEKOSHELL_BREW_PREFIX="$HOME/fakebrew" PATH=/usr/bin:/bin "$PLAYER"
  [ "$status" -eq 0 ]
  assert_contains "$output" "PANEL=1"
}

# `nekoshell music` with no player named picks the first enabled plugin tagged
# `media`, and this is the plugin that carries the tag.
@test "nekoshell music --here runs this plugin's player" {
  mkdir -p "$HOME/.cache/spotify-player"
  touch "$HOME/.cache/spotify-player/credentials.json"
  "$NK" plugin add spotify >/dev/null
  run "$NK" music --here
  [ "$status" -eq 0 ]
  assert_contains "$output" "spotify_player "
  assert_contains "$output" "PANEL=1"
  assert_not_contains "$output" "fake panel:"
}

@test "nekoshell music without --here goes through the terminal panel" {
  mkdir -p "$HOME/.cache/spotify-player"
  touch "$HOME/.cache/spotify-player/credentials.json"
  "$NK" plugin add spotify >/dev/null
  run "$NK" music
  [ "$status" -eq 0 ]
  assert_contains "$output" "fake panel:"
  assert_contains "$output" "nekoshell-spotify"
}

@test "doctor is ok once the credentials are cached" {
  mkdir -p "$HOME/.cache/spotify-player"
  touch "$HOME/.cache/spotify-player/credentials.json"
  "$NK" plugin add spotify >/dev/null
  run "$NK" doctor --plugin spotify
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +tool: spotify_player'
  assert_matches "$output" 'ok +spotify login'
}

# Logging in is a browser window and a password: an install cannot finish it,
# so an unauthenticated Spotify is a note with the command to run, never a
# failure.
@test "doctor warns with the authenticate command when there are no credentials" {
  "$NK" plugin add spotify >/dev/null
  run "$NK" doctor --plugin spotify
  [ "$status" -eq 0 ]
  assert_matches "$output" 'warn +spotify login'
  assert_contains "$output" "run: spotify_player authenticate"
}

@test "doctor fails a missing spotify_player" {
  "$NK" plugin add spotify >/dev/null
  run env PATH="/usr/bin:/bin" "$NK" doctor --plugin spotify
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +tool: spotify_player'
}

# The formula is shpotify; the command it installs is spotify. A row naming
# only one of them sends you looking for the wrong missing thing.
@test "the shpotify row names both the formula and the command" {
  "$NK" plugin add spotify >/dev/null
  run "$NK" doctor --plugin spotify
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +tool: shpotify \(spotify\)'
  run env PATH="/usr/bin:/bin" "$NK" doctor --plugin spotify
  assert_matches "$output" 'fail +tool: shpotify \(spotify\)'
}
