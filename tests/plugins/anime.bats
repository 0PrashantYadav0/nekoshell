#!/usr/bin/env bats
# The anime image provider: a picture pack fetched at a pinned commit and
# shrunk once, and a greet-image that picks a file and sizes it itself.
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  unset FAKE_CURL_FAIL FAKE_SIPS_FAILS FAKE_SIPS_SIZE NEKOSHELL_SEED ANIME_ONLY ANIME_SKIP ANIME_HEIGHT IMAGE_HEIGHT
  unset CLAUDECODE TMUX NEKOSHELL_PANEL SSH_CONNECTION NEKOSHELL_GREET_MODE NEKOSHELL_GREET_ART
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/anime"
  export PLUGIN_DIR="$P" PLUGIN_NAME=anime
  SHA="$(sed -n 's/^ANIME_SHA="\(.*\)"/\1/p' "$P/install.sh")"
  # A tarball with GitHub's archive layout: one top directory named after the
  # repository and the commit, the pictures and a README inside it.
  mkdir -p "$HOME/src/FastfetchPngs-$SHA"
  for n in Miku ZeroTwo2 SatoruGojo Loli; do
    printf 'PNG %s\n' "$n" > "$HOME/src/FastfetchPngs-$SHA/$n.png"
  done
  printf '# pictures\n' > "$HOME/src/FastfetchPngs-$SHA/README.md"
  (cd "$HOME/src" && tar czf "$HOME/pngs.tar.gz" "FastfetchPngs-$SHA")
  export FAKE_CURL_SOURCE="$HOME/pngs.tar.gz"
  ANIME_DIR="$HOME/.local/share/fastfetch-pngs"
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
  [ -x "$P/greet-image" ]
  [ ! -e "$P/greet-art" ]
}

@test "add downloads the pinned commit, shrinks every picture and lists their sizes" {
  run "$NK" plugin add anime
  [ "$status" -eq 0 ]
  assert_contains "$output" "curl -fsSL -o"
  assert_contains "$output" "/archive/$SHA.tar.gz"
  for n in Miku ZeroTwo2 SatoruGojo Loli; do
    [ -f "$ANIME_DIR/$n.png" ]
  done
  [ ! -e "$ANIME_DIR/README.md" ]
  [ "$(cat "$ANIME_DIR/.nekoshell-version")" = "$SHA" ]
  [ "$(cat "$ANIME_DIR/.nekoshell-list.txt" | tr '\n' '|')" = "Loli.png 750 1060|Miku.png 750 1060|SatoruGojo.png 750 1060|ZeroTwo2.png 750 1060|" ]
  assert_contains "$output" "anime enabled"
}

@test "the pin is a commit id and the pictures are shrunk to 640 px on the long side" {
  grep -qE '^ANIME_SHA="[0-9a-f]{40}"$' "$P/install.sh"
  "$NK" plugin add anime >/dev/null
  # The fake sips writes a stub where --out points; the stub is what is kept.
  [ "$(cat "$ANIME_DIR/Miku.png")" = "fake png" ]
  grep -q '^ANIME_PX=640$' "$P/install.sh"
}

@test "a second add does not download again" {
  "$NK" plugin add anime >/dev/null
  run "$NK" plugin add anime
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "curl"
  assert_contains "$output" "already here"
}

@test "a download that fails warns and still succeeds" {
  FAKE_CURL_FAIL=1 run "$NK" plugin add anime
  [ "$status" -eq 0 ]
  assert_contains "$output" "could not download the anime pictures"
  [ ! -d "$ANIME_DIR" ]
}

@test "pictures that cannot be shrunk are left out, and none at all keeps what is there" {
  FAKE_SIPS_FAILS=1 run "$NK" plugin add anime
  [ "$status" -eq 0 ]
  assert_contains "$output" "could not prepare any of the anime pictures"
  [ ! -e "$ANIME_DIR/.nekoshell-version" ]
  # The next add tries again rather than believing the pack is here.
  run "$NK" plugin add anime
  assert_contains "$output" "curl"
  [ -f "$ANIME_DIR/Miku.png" ]
}

@test "a dry run downloads and unpacks nothing" {
  NEKOSHELL_DRY_RUN=1 run "$NK" plugin add anime
  [ "$status" -eq 0 ]
  [ ! -d "$ANIME_DIR" ]
}

@test "greet-image prints the caption, the path and a size that keeps the proportions" {
  "$NK" plugin add anime >/dev/null
  ANIME_ONLY=miku run "$P/greet-image"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Miku" ]
  [ "${lines[1]}" = "$ANIME_DIR/Miku.png" ]
  # 750 by 1060 at 14 rows: a cell is twice as tall as it is wide, so
  # 14 * 2 * 750 / 1060 = 19.8 columns.
  [ "${lines[2]}" = "20 14" ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "the caption is the file name spaced at the capitals, without a variant number" {
  "$NK" plugin add anime >/dev/null
  ANIME_ONLY=zerotwo run "$P/greet-image"
  [ "${lines[0]}" = "Zero Two" ]
  ANIME_ONLY=gojo run "$P/greet-image"
  [ "${lines[0]}" = "Satoru Gojo" ]
  # A name that is letters and digits through, or all capitals, is left alone.
  printf 'LLawliet.png 750 1060\nRO635.png 750 1060\n' > "$ANIME_DIR/.nekoshell-list.txt"
  cp "$ANIME_DIR/Miku.png" "$ANIME_DIR/LLawliet.png"
  cp "$ANIME_DIR/Miku.png" "$ANIME_DIR/RO635.png"
  ANIME_ONLY=llaw run "$P/greet-image"
  [ "${lines[0]}" = "LLawliet" ]
  ANIME_ONLY=ro63 run "$P/greet-image"
  [ "${lines[0]}" = "RO635" ]
}

@test "the height is IMAGE_HEIGHT, or ANIME_HEIGHT over it, and the width follows the picture" {
  "$NK" plugin add anime >/dev/null
  ANIME_ONLY=miku IMAGE_HEIGHT=20 run "$P/greet-image"
  [ "${lines[2]}" = "28 20" ]
  ANIME_ONLY=miku IMAGE_HEIGHT=20 ANIME_HEIGHT=10 run "$P/greet-image"
  [ "${lines[2]}" = "14 10" ]
  # A landscape picture goes wide; a height that is not a number means 14.
  printf 'Wide.png 1000 250\n' > "$ANIME_DIR/.nekoshell-list.txt"
  cp "$ANIME_DIR/Miku.png" "$ANIME_DIR/Wide.png"
  ANIME_HEIGHT=big run "$P/greet-image"
  [ "${lines[2]}" = "112 14" ]
}

@test "ANIME_SKIP words are never drawn, and the default skips one file name" {
  "$NK" plugin add anime >/dev/null
  local seen="" seed
  for seed in 1 2 3 4 5 6 7 8 9 10 11 12; do
    seen="$seen $(NEKOSHELL_SEED=$seed "$P/greet-image" | head -1)"
  done
  assert_not_contains "$seen" "Loli"
  assert_contains "$seen" "Miku"
  assert_contains "$seen" "Zero Two"
  assert_contains "$seen" "Satoru Gojo"
  ANIME_SKIP="miku zero gojo" run "$P/greet-image"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Loli" ]
  ANIME_SKIP="miku zero gojo loli" run "$P/greet-image"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "a listed picture that is no longer on disk is not a candidate" {
  "$NK" plugin add anime >/dev/null
  rm "$ANIME_DIR/Miku.png"
  ANIME_ONLY=miku run "$P/greet-image"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "NEKOSHELL_SEED pins the draw" {
  "$NK" plugin add anime >/dev/null
  local a b
  a="$(NEKOSHELL_SEED=7 "$P/greet-image")"
  b="$(NEKOSHELL_SEED=7 "$P/greet-image")"
  [ "$a" = "$b" ]
}

@test "greet-image is quick: no process per picture" {
  "$NK" plugin add anime >/dev/null
  local ms
  ms="$(python3 -c 'import subprocess,time,sys;t=time.time();subprocess.run([sys.argv[1]],capture_output=True);print(int((time.time()-t)*1000))' "$P/greet-image")"
  [ "$ms" -lt 100 ]
}

@test "greet-image is silent and non-zero before the pack is there" {
  run "$P/greet-image"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "the greeting draws an anime picture inline, at the provider's size" {
  "$NK" plugin add anime >/dev/null
  run script -q /dev/null "$NK" greet --art anime < /dev/null
  [ "$status" -eq 0 ]
  assert_matches "$output" "--kitty $ANIME_DIR/(Miku|ZeroTwo2|SatoruGojo)\.png --logo-width 20 --logo-height 14"
  grep -qE '^(Miku|Zero Two|Satoru Gojo)$' "$HOME/.cache/nekoshell/art-name"
}

@test "nekoshell greet --art anime says so in a terminal that cannot draw images" {
  "$NK" plugin add anime >/dev/null
  sed 's/^terminal = .*/terminal = "bare"/' "$HOME/.config/nekoshell/nekoshell.toml" > "$HOME/t.toml"
  mv "$HOME/t.toml" "$HOME/.config/nekoshell/nekoshell.toml"
  run "$NK" greet --art anime
  [ "$status" -eq 1 ]
  assert_contains "$output" "anime draws pictures, which the bare terminal cannot show"
}

@test "doctor reports the pack, and warns where the terminal cannot draw it" {
  "$NK" plugin add anime >/dev/null
  run "$NK" doctor --plugin anime
  [ "$status" -eq 0 ]
  assert_matches "$output" "ok +anime pictures +${SHA:0:7}, 4 pictures"
  assert_not_contains "$output" "cannot draw"
  sed 's/^terminal = .*/terminal = "bare"/' "$HOME/.config/nekoshell/nekoshell.toml" > "$HOME/t.toml"
  mv "$HOME/t.toml" "$HOME/.config/nekoshell/nekoshell.toml"
  run "$NK" doctor --plugin anime
  [ "$status" -eq 0 ]
  assert_matches "$output" 'warn +anime pictures +the bare terminal cannot draw images; the greeting skips this provider there'
  rm -rf "$ANIME_DIR"
  run "$NK" doctor --plugin anime
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +anime pictures +missing \(nekoshell plugin add anime\)'
}
