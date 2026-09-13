#!/usr/bin/env bats
# The anime art provider: a pinned release tarball, checksummed, and a
# greet-art that picks a file itself.
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  unset FAKE_CURL_FAIL NEKOSHELL_SEED ANIME_ONLY ANIME_SKIP
  unset CLAUDECODE TMUX NEKOSHELL_PANEL SSH_CONNECTION NEKOSHELL_GREET_MODE NEKOSHELL_GREET_ART
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/anime"
  export PLUGIN_DIR="$P" PLUGIN_NAME=anime
  # A tarball with the release's layout: ./anime-colorscripts/colorscripts/*.txt.
  mkdir -p "$HOME/src/anime-colorscripts/colorscripts"
  printf '2997-hatsune-miku\n1-naruto-uzumaki\n9-fuck-you\n' > "$HOME/src/anime-colorscripts/charalist.txt"
  for n in 2997-hatsune-miku 1-naruto-uzumaki 9-fuck-you; do
    printf 'ART %s\nline2\n' "$n" > "$HOME/src/anime-colorscripts/colorscripts/$n.txt"
  done
  # One sprite too wide to sit next to the stats: 90 columns behind an escape.
  printf '\033[38;2;1;2;3m%090d\n' 0 > "$HOME/src/anime-colorscripts/colorscripts/5-wide-one.txt"
  (cd "$HOME/src" && tar czf "$HOME/anime.tar.gz" ./anime-colorscripts)
  export FAKE_CURL_SOURCE="$HOME/anime.tar.gz"
  NEKOSHELL_ANIME_SHA256="$(shasum -a 256 "$HOME/anime.tar.gz" | cut -d' ' -f1)"
  export NEKOSHELL_ANIME_SHA256
  ANIME_DIR="$HOME/.local/share/anime-colorscripts"
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

@test "add downloads the pinned release, checks it and unpacks the sprites" {
  run "$NK" plugin add anime
  [ "$status" -eq 0 ]
  assert_contains "$output" "curl -fsSL -o"
  assert_contains "$output" "releases/download/v1.1.3/anime-colorscripts.tar.gz"
  [ -f "$ANIME_DIR/colorscripts/2997-hatsune-miku.txt" ]
  [ -f "$ANIME_DIR/charalist.txt" ]
  [ "$(cat "$ANIME_DIR/.nekoshell-version")" = "v1.1.3" ]
  [ "$(cat "$ANIME_DIR/.nekoshell-list.txt" | tr '\n' ' ')" = "1-naruto-uzumaki 2997-hatsune-miku 9-fuck-you " ]
  assert_contains "$output" "anime enabled"
}

@test "the recorded checksum is a sha256 and the tarball is the v1.1.3 asset" {
  grep -q '^ANIME_VERSION="v1.1.3"' "$P/install.sh"
  grep -qE ':-[0-9a-f]{64}\}' "$P/install.sh"
}

@test "a second add does not download again" {
  "$NK" plugin add anime >/dev/null
  run "$NK" plugin add anime
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "curl"
  assert_contains "$output" "already here"
}

@test "a checksum mismatch keeps what is there and still succeeds" {
  NEKOSHELL_ANIME_SHA256="0000000000000000000000000000000000000000000000000000000000000000" run "$NK" plugin add anime
  [ "$status" -eq 0 ]
  assert_contains "$output" "does not match the recorded checksum"
  [ ! -d "$ANIME_DIR/colorscripts" ]
}

@test "a download that fails warns and still succeeds" {
  FAKE_CURL_FAIL=1 run "$NK" plugin add anime
  [ "$status" -eq 0 ]
  assert_contains "$output" "could not download anime-colorscripts"
  [ ! -d "$ANIME_DIR/colorscripts" ]
}

@test "a dry run downloads and unpacks nothing" {
  NEKOSHELL_DRY_RUN=1 run "$NK" plugin add anime
  [ "$status" -eq 0 ]
  [ ! -d "$ANIME_DIR" ]
}

@test "greet-art captions the file name and prints the sprite" {
  "$NK" plugin add anime >/dev/null
  ANIME_ONLY=miku run "$P/greet-art"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Hatsune Miku" ]
  [ "${lines[1]}" = "ART 2997-hatsune-miku" ]
  [ "${lines[2]}" = "line2" ]
}

@test "ANIME_SKIP words are never drawn, and the default skips the rude one" {
  "$NK" plugin add anime >/dev/null
  local seen="" seed
  for seed in 1 2 3 4 5 6 7 8 9 10; do
    seen="$seen $(NEKOSHELL_SEED=$seed "$P/greet-art" | head -1)"
  done
  assert_not_contains "$seen" "Fuck"
  assert_not_contains "$seen" "Wide One"
  assert_contains "$seen" "Hatsune Miku"
  assert_contains "$seen" "Naruto Uzumaki"
  ANIME_SKIP="miku naruto" run "$P/greet-art"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Fuck You" ]
  ANIME_SKIP="miku naruto fuck" run "$P/greet-art"
  [ "$status" -eq 1 ]
}

@test "without the list every sprite is a candidate" {
  "$NK" plugin add anime >/dev/null
  rm "$ANIME_DIR/.nekoshell-list.txt"
  ANIME_ONLY=wide run "$P/greet-art"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Wide One" ]
}

@test "greet-art is quick: no process per sprite" {
  "$NK" plugin add anime >/dev/null
  local ms
  ms="$(python3 -c 'import subprocess,time,sys;t=time.time();subprocess.run([sys.argv[1]],capture_output=True);print(int((time.time()-t)*1000))' "$P/greet-art")"
  [ "$ms" -lt 100 ]
}

@test "greet-art is silent and non-zero before the pack is there" {
  run "$P/greet-art"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "the greeting draws an anime sprite through the provider" {
  "$NK" plugin add anime >/dev/null
  run script -q /dev/null "$NK" greet --art anime < /dev/null
  assert_contains "$output" "--file-raw - stdin=2"
  grep -qE 'Hatsune Miku|Naruto Uzumaki' "$HOME/.cache/nekoshell/art-name"
}

@test "doctor reports the pack" {
  "$NK" plugin add anime >/dev/null
  run "$NK" doctor --plugin anime
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +anime-colorscripts +v1\.1\.3, 3 of 4 sprites fit'
  rm -rf "$ANIME_DIR"
  run "$NK" doctor --plugin anime
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +anime-colorscripts +missing \(nekoshell plugin add anime\)'
}
