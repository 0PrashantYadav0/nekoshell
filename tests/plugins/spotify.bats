#!/usr/bin/env bats
load ../helpers

# The Spotify player. spotify_player streams on its own (Premium); shpotify
# drives the desktop app over AppleScript and is the fallback. The plugin is
# tagged `media`, which is what `nekoshell music` looks for.
#
# app.toml is copied once and is the user's (their client id goes in it);
# theme.toml is rendered for the flavour in force and is nekoshell's.

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
  unset NEKOSHELL_DRY_RUN
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/spotify"
  PLAYER="$P/bin/nekoshell-spotify"
  APP="$HOME/.config/spotify-player/app.toml"
  THEME="$HOME/.config/spotify-player/theme.toml"
  CACHE="$HOME/.cache/spotify-player"
  ID1="0123456789abcdef0123456789abcdef"
  ID2="fedcba9876543210fedcba9876543210"
  SHARED="d420a117a32841c2b3474932e49fb54b"
}
teardown() { teardown_tmp_home; }

# set_flavour FLAVOUR: what a theme switch records, without rendering the rest.
set_flavour() {
  sed "s/^theme_resolved = .*/theme_resolved = \"$1\"/" "$HOME/.config/nekoshell/nekoshell.toml" > "$HOME/t.toml"
  mv "$HOME/t.toml" "$HOME/.config/nekoshell/nekoshell.toml"
}

# app_summary: the settings that matter, parsed from the user's app.toml.
app_summary() {
  python3 -c "
import tomllib
a=tomllib.load(open('$APP','rb'))
print(a.get('theme'), a.get('client_id'), a['device']['name'], a['device']['volume'], a['device']['bitrate'], a['client_port'], a['login_redirect_uri'])"
}

# theme_summary: the theme's name and background, parsed from the rendered theme.toml.
theme_summary() {
  python3 -c "
import tomllib
t=tomllib.load(open('$THEME','rb'))
print(t['themes'][0]['name'], t['themes'][0]['palette']['background'])"
}

@test "plugin.toml is complete and the README has its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  grep -q '^requires *= *\["spotify_player", "shpotify"\]$' "$P/plugin.toml"
  grep -q '^tags *= *\["media"\]$' "$P/plugin.toml"
  grep -q '^copy_guard *= *\[".config/spotify-player/app.toml"\]$' "$P/plugin.toml"
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
  grep -qF "authenticate" "$P/README.md"
  grep -qF "https://developer.spotify.com/dashboard" "$P/README.md"
  grep -qF "http://127.0.0.1:8989/login" "$P/README.md"
  grep -qF "nekoshell spotify client-id" "$P/README.md"
}

# The shipped app.toml has no client id of its own: it explains where to get
# one, with the exact redirect URI the dashboard needs.
@test "the shipped app.toml documents the client id and leaves it unset" {
  src="$P/files/copy/.config/spotify-player/app.toml"
  [ ! -e "$P/files/link" ]
  grep -qF "https://developer.spotify.com/dashboard" "$src"
  grep -q '^login_redirect_uri = "http://127.0.0.1:8989/login"$' "$src"
  grep -q '^# client_id = ' "$src"
  run grep -c '^client_id' "$src"
  [ "$output" = "0" ]
}

@test "add installs both tools, copies app.toml and renders theme.toml for mocha" {
  run "$NK" plugin add spotify
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install spotify_player shpotify"
  [ -f "$APP" ]
  [ ! -L "$APP" ]
  [ -f "$THEME" ]
  [ ! -L "$THEME" ]
  assert_contains "$(head -n 1 "$THEME")" "nekoshell"
  assert_not_contains "$(cat "$THEME")" "@@"
  run app_summary
  [ "$output" = "catppuccin_mocha None nekoshell 70 320 8080 http://127.0.0.1:8989/login" ]
  run theme_summary
  [ "$output" = "catppuccin_mocha #1e1e2e" ]
}

@test "a second add keeps your app.toml" {
  "$NK" plugin add spotify >/dev/null
  sed 's/^volume = 70$/volume = 55/' "$APP" > "$HOME/t.toml" && mv "$HOME/t.toml" "$APP"
  run "$NK" plugin add spotify
  [ "$status" -eq 0 ]
  run app_summary
  [ "$output" = "catppuccin_mocha None nekoshell 55 320 8080 http://127.0.0.1:8989/login" ]
}

@test "nekoshell theme latte re-renders theme.toml and rewrites only the theme line" {
  "$NK" plugin add spotify >/dev/null
  sed 's/^volume = 70$/volume = 55/' "$APP" > "$HOME/t.toml" && mv "$HOME/t.toml" "$APP"
  before_lines="$(wc -l < "$APP" | tr -d ' ')"
  run "$NK" theme latte
  [ "$status" -eq 0 ]
  run theme_summary
  [ "$output" = "catppuccin_latte #eff1f5" ]
  run app_summary
  [ "$output" = "catppuccin_latte None nekoshell 55 320 8080 http://127.0.0.1:8989/login" ]
  [ "$(wc -l < "$APP" | tr -d ' ')" = "$before_lines" ]
  run grep -c '^theme = ' "$APP"
  [ "$output" = "1" ]
  # the comments are the user's too
  grep -qF "https://developer.spotify.com/dashboard" "$APP"
}

# A theme line the user took out is not put back: the hook rewrites, never adds.
@test "the theme hook leaves an app.toml without a theme line alone" {
  "$NK" plugin add spotify >/dev/null
  grep -v '^theme = ' "$APP" > "$HOME/t.toml" && mv "$HOME/t.toml" "$APP"
  run "$NK" theme latte
  [ "$status" -eq 0 ]
  run grep -c '^theme = ' "$APP"
  [ "$output" = "0" ]
  run theme_summary
  [ "$output" = "catppuccin_latte #eff1f5" ]
}

@test "copy_guard leaves an existing app.toml alone and says so" {
  mkdir -p "$HOME/.config/spotify-player"
  printf 'client_port = 9999\n\n[device]\nname = "mine"\n' > "$APP"
  run "$NK" plugin add spotify
  [ "$status" -eq 0 ]
  assert_contains "$output" "spotify: .config/spotify-player/app.toml exists; left your config alone"
  [ "$(cat "$APP")" = "$(printf 'client_port = 9999\n\n[device]\nname = "mine"\n')" ]
  [ -f "$THEME" ]
}

# The earlier version linked app.toml into the checkout, where a client_id
# line could not go without editing the repo. That link is replaced by a copy.
@test "the install hook replaces a stale app.toml link into the checkout with a copy" {
  mkdir -p "$HOME/.config/spotify-player"
  ln -s "$P/files/copy/.config/spotify-player/app.toml" "$APP"
  ln -s "$P/files/theme.toml.tmpl" "$THEME"
  run "$NK" plugin add spotify
  [ "$status" -eq 0 ]
  assert_contains "$output" "app.toml was a link into the checkout"
  [ -f "$APP" ]
  [ ! -L "$APP" ]
  [ -f "$THEME" ]
  [ ! -L "$THEME" ]
  run app_summary
  [ "$output" = "catppuccin_mocha None nekoshell 70 320 8080 http://127.0.0.1:8989/login" ]
  run theme_summary
  [ "$output" = "catppuccin_mocha #1e1e2e" ]
  # and the template it used to point at is still a template
  grep -q '@@HEX:base@@' "$P/files/theme.toml.tmpl"
}

@test "the install hook leaves a foreign app.toml link alone" {
  mkdir -p "$HOME/.config/spotify-player" "$HOME/dotfiles"
  printf 'theme = "mine"\n' > "$HOME/dotfiles/app.toml"
  ln -s "$HOME/dotfiles/app.toml" "$APP"
  run "$NK" plugin add spotify
  [ "$status" -eq 0 ]
  [ -L "$APP" ]
  [ "$(cat "$HOME/dotfiles/app.toml")" = 'theme = "mine"' ]
}

@test "a dry run prints the migration and changes nothing" {
  mkdir -p "$HOME/.config/spotify-player"
  ln -s "$P/files/copy/.config/spotify-player/app.toml" "$APP"
  run env NEKOSHELL_DRY_RUN=1 "$NK" plugin add spotify
  [ "$status" -eq 0 ]
  assert_contains "$output" "rm -f $APP"
  assert_contains "$output" "cp $P/files/copy/.config/spotify-player/app.toml $APP"
  [ -L "$APP" ]
  [ ! -e "$THEME" ]
}

@test "remove keeps app.toml and removes the rendered theme.toml" {
  "$NK" plugin add spotify >/dev/null
  run "$NK" plugin remove spotify
  [ "$status" -eq 0 ]
  [ -f "$APP" ]
  [ ! -e "$THEME" ]
  [ "$(grep '^plugins' "$HOME/.config/nekoshell/nekoshell.toml")" = 'plugins = []' ]
}

@test "remove leaves a theme.toml you wrote alone" {
  "$NK" plugin add spotify >/dev/null
  printf '[[themes]]\nname = "mine"\n' > "$THEME"
  run "$NK" plugin remove spotify
  [ "$status" -eq 0 ]
  [ "$(cat "$THEME")" = "$(printf '[[themes]]\nname = "mine"\n')" ]
}

@test "nekoshell help lists the spotify command" {
  run "$NK" help
  [ "$status" -eq 0 ]
  assert_matches "$output" 'spotify +\(plugin spotify'
}

@test "nekoshell spotify client-id writes the line and says to log in" {
  "$NK" plugin add spotify >/dev/null
  run "$NK" spotify client-id "$ID1"
  [ "$status" -eq 0 ]
  assert_contains "$output" "nekoshell spotify login"
  run app_summary
  [ "$output" = "catppuccin_mocha $ID1 nekoshell 70 320 8080 http://127.0.0.1:8989/login" ]
  # a second id replaces the line rather than adding another
  run "$NK" spotify client-id "$ID2"
  [ "$status" -eq 0 ]
  run grep -c '^client_id = ' "$APP"
  [ "$output" = "1" ]
  run app_summary
  [ "$output" = "catppuccin_mocha $ID2 nekoshell 70 320 8080 http://127.0.0.1:8989/login" ]
}

@test "nekoshell spotify client-id validates the id" {
  "$NK" plugin add spotify >/dev/null
  run "$NK" spotify client-id not-an-id
  [ "$status" -eq 2 ]
  assert_contains "$output" "32 hex characters"
  run "$NK" spotify client-id "${ID1}0"
  [ "$status" -eq 2 ]
  run "$NK" spotify client-id "$SHARED"
  [ "$status" -eq 1 ]
  assert_contains "$output" "shared id"
  run "$NK" spotify client-id
  [ "$status" -eq 2 ]
  run grep -c '^client_id = ' "$APP"
  [ "$output" = "0" ]
}

@test "nekoshell spotify client-id needs the plugin enabled and a real app.toml" {
  run "$NK" spotify client-id "$ID1"
  [ "$status" -eq 2 ]
  assert_contains "$output" "nekoshell plugin add spotify"
  "$NK" plugin add spotify >/dev/null
  rm "$APP"
  run "$NK" spotify client-id "$ID1"
  [ "$status" -eq 1 ]
  assert_contains "$output" "nekoshell plugin add spotify"
}

@test "a dry-run client-id prints the move and leaves app.toml alone" {
  "$NK" plugin add spotify >/dev/null
  run env NEKOSHELL_DRY_RUN=1 "$NK" spotify client-id "$ID1"
  [ "$status" -eq 0 ]
  assert_contains "$output" "mv $APP.nekoshell.tmp $APP"
  [ ! -e "$APP.nekoshell.tmp" ]
  run grep -c '^client_id = ' "$APP"
  [ "$output" = "0" ]
}

@test "nekoshell spotify -h prints the usage with the dashboard and the redirect URI" {
  "$NK" plugin add spotify >/dev/null
  run "$NK" spotify --help
  [ "$status" -eq 0 ]
  assert_contains "$output" "usage: nekoshell spotify"
  assert_contains "$output" "https://developer.spotify.com/dashboard"
  assert_contains "$output" "http://127.0.0.1:8989/login"
  run "$NK" spotify
  [ "$status" -eq 2 ]
  run "$NK" spotify bogus
  [ "$status" -eq 2 ]
}

@test "nekoshell spotify login forgets the cached login and authenticates" {
  "$NK" plugin add spotify >/dev/null
  mkdir -p "$CACHE"
  touch "$CACHE/credentials.json" "$CACHE/${SHARED}_token.json" "$CACHE/Playlists_cache.json"
  run "$NK" spotify login
  [ "$status" -eq 0 ]
  assert_contains "$output" "spotify_player authenticate"
  [ ! -e "$CACHE/credentials.json" ]
  [ ! -e "$CACHE/${SHARED}_token.json" ]
  [ -e "$CACHE/Playlists_cache.json" ]
}

@test "nekoshell spotify logout removes the credentials and the tokens" {
  "$NK" plugin add spotify >/dev/null
  mkdir -p "$CACHE"
  touch "$CACHE/credentials.json" "$CACHE/${SHARED}_token.json" "$CACHE/${ID1}_token.json" "$CACHE/Playlists_cache.json"
  run "$NK" spotify logout
  [ "$status" -eq 0 ]
  assert_contains "$output" "logged out"
  [ ! -e "$CACHE/credentials.json" ]
  [ ! -e "$CACHE/${SHARED}_token.json" ]
  [ ! -e "$CACHE/${ID1}_token.json" ]
  [ -e "$CACHE/Playlists_cache.json" ]
  assert_not_contains "$output" "Playlists_cache"
}

@test "the player runs spotify_player when credentials are cached" {
  mkdir -p "$CACHE"
  touch "$CACHE/credentials.json"
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

# A terminal panel runs a profile's command without a login shell, so it starts
# with launchd's PATH and nothing from Homebrew on it. The launcher has to put
# the prefixes back itself or it always reports spotify_player missing.
@test "the panel finds spotify_player with only launchd's PATH" {
  mkdir -p "$HOME/fakebrew/bin" "$CACHE"
  cp "$REPO_ROOT/tests/fakes/spotify_player" "$HOME/fakebrew/bin/spotify_player"
  touch "$CACHE/credentials.json"
  run env NEKOSHELL_BREW_PREFIX="$HOME/fakebrew" PATH=/usr/bin:/bin "$PLAYER"
  [ "$status" -eq 0 ]
  assert_contains "$output" "PANEL=1"
}

# `nekoshell music` with no player named picks the first enabled plugin tagged
# `media`, and this is the plugin that carries the tag. The player runs in
# this window unless --panel asks for the terminal's panel.
@test "nekoshell music runs this plugin's player in this window" {
  mkdir -p "$CACHE"
  touch "$CACHE/credentials.json"
  "$NK" plugin add spotify >/dev/null
  run "$NK" music
  [ "$status" -eq 0 ]
  assert_contains "$output" "spotify_player "
  assert_contains "$output" "PANEL=1"
  assert_not_contains "$output" "fake panel:"
}

@test "nekoshell music --panel goes through the terminal panel" {
  mkdir -p "$CACHE"
  touch "$CACHE/credentials.json"
  "$NK" plugin add spotify >/dev/null
  run "$NK" music --panel
  [ "$status" -eq 0 ]
  assert_contains "$output" "fake panel:"
  assert_contains "$output" "nekoshell-spotify"
}

@test "doctor is ok once the credentials are cached" {
  mkdir -p "$CACHE"
  touch "$CACHE/credentials.json"
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

# Registering an id is a dashboard and a login, which an install cannot do
# either, so the shared id is a note with the command, not a failure.
@test "doctor warns on the shared client id and is ok with a personal one" {
  "$NK" plugin add spotify >/dev/null
  run "$NK" doctor --plugin spotify
  [ "$status" -eq 0 ]
  assert_matches "$output" 'warn +spotify client id'
  assert_contains "$output" "spotify_player's shared id is rate-limited by Spotify (slow start); run: nekoshell spotify client-id <id> (see plugins/spotify/README.md)"
  # the shared id written out by hand is still the shared id
  printf 'theme = "catppuccin_mocha"\nclient_id = "%s"\n\n[device]\nname = "nekoshell"\n' "$SHARED" > "$APP"
  run "$NK" doctor --plugin spotify
  [ "$status" -eq 0 ]
  assert_matches "$output" 'warn +spotify client id'
  "$NK" spotify client-id "$ID1" >/dev/null
  run "$NK" doctor --plugin spotify
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +spotify client id +012345\.\.\.'
  assert_not_contains "$output" "$ID1"
}

@test "doctor checks that theme.toml is rendered for the flavour in force" {
  "$NK" plugin add spotify >/dev/null
  run "$NK" doctor --plugin spotify
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +spotify theme +catppuccin_mocha'
  set_flavour latte
  run "$NK" doctor --plugin spotify
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +spotify theme'
  assert_contains "$output" "nekoshell theme latte"
  "$NK" theme latte >/dev/null
  run "$NK" doctor --plugin spotify
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +spotify theme +catppuccin_latte'
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
