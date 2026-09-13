#!/usr/bin/env bats
load ../helpers

# The greeting: a sprite from an enabled art provider plugin, or a picture
# from your art pack, next to the machine stats fastfetch prints. It runs on
# every new interactive shell, so the whole thing is built around never
# costing anything and never failing one: every problem exits 0 quietly.

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  unset CLAUDECODE TMUX NEKOSHELL_PANEL SSH_CONNECTION NEKOSHELL_NO_GREET NEKOSHELL_GREET_SSH NEKOSHELL_GREET_MODE NEKOSHELL_GREET_ART FAKEART_FAIL FAKEART2_FAIL
  # A developer running the tests from a nekoshell shell has NEKOSHELL_ROOT
  # exported, pointing at their own checkout. The greeting prefers it over the
  # recorded root, so it has to go: these tests are about this checkout, and
  # the run below is what proves the recorded root is found without it.
  unset NEKOSHELL_ROOT
  # The engine looks for providers among the enabled plugins under
  # NEKOSHELL_PLUGINS_DIR. A directory of links carries the real greet plugin
  # next to the two fixture providers.
  export NEKOSHELL_PLUGINS_DIR="$HOME/plugins"
  mkdir -p "$NEKOSHELL_PLUGINS_DIR"
  ln -s "$REPO_ROOT/plugins/greet" "$NEKOSHELL_PLUGINS_DIR/greet"
  ln -s "$REPO_ROOT/tests/fixtures/plugins/fakeart" "$NEKOSHELL_PLUGINS_DIR/fakeart"
  ln -s "$REPO_ROOT/tests/fixtures/plugins/fakeart2" "$NEKOSHELL_PLUGINS_DIR/fakeart2"
  mkdir -p "$HOME/.config/nekoshell/art" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = ["greet", "fakeart"]\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/greet"
}
teardown() { teardown_tmp_home; }

# greet ARGS: run the greeting with a pty, because it says nothing at all when
# stdout is not a tty. script glues a ^D onto the first line on macOS.
greet() {
  local out rc
  out="$(script -q /dev/null "$P/bin/nekoshell-greet" "$@" < /dev/null)"
  rc=$?
  printf '%s\n' "$out" | sed $'1s/^\^D\b\b//'
  return $rc
}

# set_terminal ID: point the recorded config at another terminal adapter.
set_terminal() {
  sed "s/^terminal = .*/terminal = \"$1\"/" "$HOME/.config/nekoshell/nekoshell.toml" > "$HOME/t.toml"
  mv "$HOME/t.toml" "$HOME/.config/nekoshell/nekoshell.toml"
}

# set_flavour FLAVOUR: what a theme switch records, without rendering the rest.
set_flavour() {
  sed "s/^theme_resolved = .*/theme_resolved = \"$1\"/" "$HOME/.config/nekoshell/nekoshell.toml" > "$HOME/t.toml"
  mv "$HOME/t.toml" "$HOME/.config/nekoshell/nekoshell.toml"
}

# set_plugins LIST: rewrite the enabled list, e.g. set_plugins '"greet", "fakeart"'.
set_plugins() {
  sed "s/^plugins = .*/plugins = [$1]/" "$HOME/.config/nekoshell/nekoshell.toml" > "$HOME/t.toml"
  mv "$HOME/t.toml" "$HOME/.config/nekoshell/nekoshell.toml"
}

# rendered_rows: the module list and the two colours out of the rendered config.
rendered_rows() {
  sed -e 's://[^"]*$::' "$HOME/.config/fastfetch/config.jsonc" | python3 -c '
import json,sys
d=json.load(sys.stdin)
rows=[m if isinstance(m,str) else m["type"] for m in d["modules"]]
print(" ".join(rows))
print(d["display"]["color"]["keys"])
print(d["display"]["color"]["title"])'
}

@test "plugin.toml is complete and the README has its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
}

@test "add installs fastfetch, clones nothing, copies greet.conf and renders the fastfetch config" {
  run "$NK" plugin add greet
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install fastfetch"
  assert_not_contains "$output" "git clone"
  [ -f "$HOME/.config/nekoshell/greet.conf" ]
  [ ! -L "$HOME/.config/nekoshell/greet.conf" ]
  grep -q '^ART=auto' "$HOME/.config/nekoshell/greet.conf"
  grep -q '^SPRITE_SHARE=70' "$HOME/.config/nekoshell/greet.conf"
  [ -f "$HOME/.config/fastfetch/config.jsonc" ]
  [ ! -L "$HOME/.config/fastfetch/config.jsonc" ]
}

@test "greet.conf is yours: a second add keeps your edit" {
  "$NK" plugin add greet >/dev/null
  printf 'SPRITE_SHARE=5\n' >> "$HOME/.config/nekoshell/greet.conf"
  "$NK" plugin add greet >/dev/null
  grep -q 'SPRITE_SHARE=5' "$HOME/.config/nekoshell/greet.conf"
}

@test "the rendered fastfetch config is valid JSONC with the expected rows in order" {
  "$NK" plugin add greet >/dev/null
  run rendered_rows
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "title separator os host uptime shell terminal cpu memory disk battery wifi localip packages command break colors" ]
  [ "${lines[1]}" = "38;2;203;166;247" ]
  [ "${lines[2]}" = "38;2;137;180;250" ]
}

# The colours are the only thing the flavour changes; the module list must not
# drift between flavours.
@test "latte renders the same rows with its own key and title colours" {
  "$NK" plugin add greet >/dev/null
  set_flavour latte
  "$NK" plugin add greet >/dev/null
  run rendered_rows
  [ "${lines[0]}" = "title separator os host uptime shell terminal cpu memory disk battery wifi localip packages command break colors" ]
  [ "${lines[1]}" = "38;2;136;57;239" ]
  [ "${lines[2]}" = "38;2;30;102;245" ]
}

# The fastfetch config used to be stowed. A render through a leftover link
# would write straight into the checkout.
@test "the theme hook replaces a stale link into the checkout with a real file" {
  mkdir -p "$HOME/.config/fastfetch"
  ln -sfn "$P/fastfetch.jsonc.tmpl" "$HOME/.config/fastfetch/config.jsonc"
  "$NK" plugin add greet >/dev/null
  [ ! -L "$HOME/.config/fastfetch/config.jsonc" ]
  [ -f "$HOME/.config/fastfetch/config.jsonc" ]
  ! grep -q '@@sgr:' "$HOME/.config/fastfetch/config.jsonc"
  # and the template it used to point at is still a template
  grep -q '@@sgr:' "$P/fastfetch.jsonc.tmpl"
}

@test "fastfetch accepts the rendered config" {
  # The fakes dir is on PATH, so look for the real binary on the PATH the
  # run below uses; CI has no fastfetch and must skip, not fail.
  local real_path="/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"
  PATH="$real_path" command -v fastfetch >/dev/null || skip "fastfetch not installed"
  "$NK" plugin add greet >/dev/null
  run env PATH="$real_path" \
    fastfetch --config "$HOME/.config/fastfetch/config.jsonc" --logo none --pipe
  [ "$status" -eq 0 ]
  assert_contains "$output" "Storage"
  assert_contains "$output" "Packages"
}

@test "silent when CLAUDECODE is set" {
  "$NK" plugin add greet >/dev/null
  CLAUDECODE=1 run greet
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "silent inside tmux and inside the panel" {
  "$NK" plugin add greet >/dev/null
  TMUX=/tmp/x run greet; [ -z "$output" ]
  NEKOSHELL_PANEL=1 run greet; [ -z "$output" ]
}

@test "silent over ssh unless opted in" {
  "$NK" plugin add greet >/dev/null
  SSH_CONNECTION="1 2 3 4" run greet; [ -z "$output" ]
  SSH_CONNECTION="1 2 3 4" NEKOSHELL_GREET_SSH=1 NEKOSHELL_SEED=1 run greet
  assert_contains "$output" "fastfetch"
}

# The opt-in is exactly 1, the value late.zsh looks for too. Anything else,
# `0` most of all, has to read as the no it looks like.
@test "the ssh opt-in is exactly 1" {
  "$NK" plugin add greet >/dev/null
  SSH_CONNECTION="1 2 3 4" NEKOSHELL_GREET_SSH=0 NEKOSHELL_SEED=1 run greet
  [ -z "$output" ]
  SSH_CONNECTION="1 2 3 4" NEKOSHELL_GREET_SSH=yes NEKOSHELL_SEED=1 run greet
  [ -z "$output" ]
  grep -q 'NEKOSHELL_GREET_SSH:-}" != 1' "$P/bin/nekoshell-greet"
  grep -q 'NEKOSHELL_GREET_SSH:-}" == 1' "$P/late.zsh"
}

@test "silent when stdout is not a tty" {
  "$NK" plugin add greet >/dev/null
  run "$P/bin/nekoshell-greet"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# The tty gate is for the automatic greeting only. Someone who typed the
# command asked for the output and should get it, pipe or no pipe.
@test "an asked-for greeting prints into a pipe" {
  "$NK" plugin add greet >/dev/null
  run bash -c "'$NK' greet --text | cat"
  [ "$status" -eq 0 ]
  assert_contains "$output" "--file-raw -"
}

@test "prints nothing when fastfetch is missing" {
  "$NK" plugin add greet >/dev/null
  PATH="/usr/bin:/bin" NEKOSHELL_SEED=1 run greet
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- art providers ----------------------------------------------------------
# A provider is an enabled plugin with an executable greet-art: caption on
# the first line, sprite after it. The fixtures under tests/fixtures/plugins
# stand in for pokemon, anime and the rest.

@test "a provider's sprite goes into fastfetch and its caption into the cache" {
  NEKOSHELL_SEED=1 run greet
  [ "$status" -eq 0 ]
  assert_contains "$output" "--file-raw - stdin=3"
  [ "$(cat "$HOME/.cache/nekoshell/art-name")" = "Fake Art · one" ]
}

@test "ART=auto picks among the enabled providers with equal odds" {
  set_plugins '"greet", "fakeart", "fakeart2"'
  local seen="" seed
  for seed in 1 2 3 4 5 6 7 8; do
    # The cache is cleared first, so a run that drew nothing is seen as an
    # empty caption rather than as the previous seed's.
    rm -f "$HOME/.cache/nekoshell/art-name"
    NEKOSHELL_SEED=$seed NEKOSHELL_GREET_MODE=text greet >/dev/null
    [ -s "$HOME/.cache/nekoshell/art-name" ]
    seen="$seen $(cat "$HOME/.cache/nekoshell/art-name")"
  done
  assert_contains "$seen" "Fake Art · one"
  assert_contains "$seen" "Fake Art · two"
}

@test "ART weights: a zero weight never draws, a name that is not enabled is skipped" {
  set_plugins '"greet", "fakeart", "fakeart2"'
  printf 'ART="fakeart:0,fakeart2:5,nothere:9"\n' > "$HOME/.config/nekoshell/greet.conf"
  local seed
  for seed in 1 2 3 4 5; do
    NEKOSHELL_SEED=$seed NEKOSHELL_GREET_MODE=text greet >/dev/null
    [ "$(cat "$HOME/.cache/nekoshell/art-name")" = "Fake Art · two" ]
  done
}

@test "a plugin that is enabled but is not a provider is not drawn from" {
  set_plugins '"greet", "fakeart2"'
  printf 'ART="greet,fakeart2"\n' > "$HOME/.config/nekoshell/greet.conf"
  NEKOSHELL_SEED=3 NEKOSHELL_GREET_MODE=text run greet
  [ "$(cat "$HOME/.cache/nekoshell/art-name")" = "Fake Art · two" ]
}

@test "a provider that draws nothing gives way to the stats alone" {
  FAKEART_FAIL=1 NEKOSHELL_SEED=1 run greet
  [ "$status" -eq 0 ]
  assert_contains "$output" "--logo none"
  assert_not_contains "$output" "--file-raw"
  [ ! -s "$HOME/.cache/nekoshell/art-name" ]
}

@test "no provider enabled: the stats alone" {
  set_plugins '"greet"'
  NEKOSHELL_SEED=1 run greet
  [ "$status" -eq 0 ]
  assert_contains "$output" "--logo none"
}

@test "NEKOSHELL_GREET_ART forces a provider" {
  set_plugins '"greet", "fakeart", "fakeart2"'
  NEKOSHELL_GREET_ART=fakeart2 NEKOSHELL_SEED=1 run greet
  [ "$(cat "$HOME/.cache/nekoshell/art-name")" = "Fake Art · two" ]
}

@test "greet.conf keys reach the provider" {
  printf 'FAKEART_FAIL=1\n' > "$HOME/.config/nekoshell/greet.conf"
  NEKOSHELL_SEED=1 run greet
  assert_contains "$output" "--logo none"
}

# --- the image branch -------------------------------------------------------
# The image branch is a question about the terminal, not about TERM_PROGRAM: it
# is taken only when the adapter says it can draw images. The `fake` fixture
# can; `bare` (the contract's own defaults) cannot.

@test "the image branch is taken on a terminal whose capabilities include images" {
  "$NK" plugin add greet >/dev/null
  cp "$P/art/neko.png" "$HOME/.config/nekoshell/art/"
  echo 'SPRITE_SHARE=0' > "$HOME/.config/nekoshell/greet.conf"
  NEKOSHELL_SEED=1 run greet
  assert_contains "$output" "--kitty $HOME/.config/nekoshell/art/neko.png --logo-width 28 --logo-height 14"
  [ "$(cat "$HOME/.cache/nekoshell/art-name")" = "neko.png" ]
}

@test "the old POKEMON_SHARE key still sets the sprite share" {
  cp "$P/art/neko.png" "$HOME/.config/nekoshell/art/"
  echo 'POKEMON_SHARE=0' > "$HOME/.config/nekoshell/greet.conf"
  NEKOSHELL_SEED=1 run greet
  assert_contains "$output" "--kitty"
  echo 'POKEMON_SHARE=100' > "$HOME/.config/nekoshell/greet.conf"
  NEKOSHELL_SEED=1 run greet
  assert_contains "$output" "--file-raw -"
}

@test "a terminal that cannot draw images falls back to the sprite" {
  cp "$P/art/neko.png" "$HOME/.config/nekoshell/art/"
  echo 'SPRITE_SHARE=0' > "$HOME/.config/nekoshell/greet.conf"
  set_terminal bare
  NEKOSHELL_SEED=1 run greet
  assert_contains "$output" "--file-raw -"
  assert_not_contains "$output" "--kitty"
  assert_not_contains "$output" "--iterm"
}

# iTerm2 draws its own inline images with a protocol of its own; everything
# else that can draw images speaks kitty's.
@test "an image-capable iterm2 gets --iterm rather than --kitty" {
  cp "$P/art/neko.png" "$HOME/.config/nekoshell/art/"
  echo 'SPRITE_SHARE=0' > "$HOME/.config/nekoshell/greet.conf"
  mkdir -p "$HOME/terms/iterm2"
  printf 'terminal_name() { echo iterm2; }\nterminal_capabilities() { echo "truecolor images"; }\n' \
    > "$HOME/terms/iterm2/adapter.sh"
  set_terminal iterm2
  NEKOSHELL_TERMINALS_DIR="$HOME/terms" NEKOSHELL_SEED=1 run greet
  assert_contains "$output" "--iterm $HOME/.config/nekoshell/art/neko.png"
}

@test "falls back to the sprite when the art pack is empty" {
  echo 'SPRITE_SHARE=0' > "$HOME/.config/nekoshell/greet.conf"
  NEKOSHELL_SEED=1 run greet
  assert_contains "$output" "--file-raw -"
}

@test "NEKOSHELL_GREET_MODE forces either branch" {
  cp "$P/art/neko.png" "$HOME/.config/nekoshell/art/"
  # share 100 means the roll can never choose the image on its own
  echo 'SPRITE_SHARE=100' > "$HOME/.config/nekoshell/greet.conf"
  NEKOSHELL_GREET_MODE=image NEKOSHELL_SEED=1 run greet
  assert_contains "$output" "--kitty"
  echo 'SPRITE_SHARE=0' > "$HOME/.config/nekoshell/greet.conf"
  NEKOSHELL_GREET_MODE=text NEKOSHELL_SEED=1 run greet
  assert_contains "$output" "--file-raw -"
  assert_not_contains "$output" "--kitty"
}

@test "NEKOSHELL_GREET_TIME prints a millisecond line" {
  "$NK" plugin add greet >/dev/null
  NEKOSHELL_GREET_TIME=1 NEKOSHELL_SEED=1 run greet
  last="${lines[${#lines[@]}-1]}"
  last="${last%$'\r'}"
  assert_matches "$last" '^greet: [0-9]+ ms$'
}

# --- the command ------------------------------------------------------------

@test "nekoshell greet --text and --image reach the two branches" {
  "$NK" plugin add greet >/dev/null
  cp "$P/art/neko.png" "$HOME/.config/nekoshell/art/"
  echo 'SPRITE_SHARE=100' > "$HOME/.config/nekoshell/greet.conf"
  run script -q /dev/null "$NK" greet --image < /dev/null
  assert_contains "$output" "--kitty"
  echo 'SPRITE_SHARE=0' > "$HOME/.config/nekoshell/greet.conf"
  run script -q /dev/null "$NK" greet --text < /dev/null
  assert_contains "$output" "--file-raw -"
}

@test "nekoshell greet --art forces a provider and refuses one that is not enabled" {
  set_plugins '"greet", "fakeart", "fakeart2"'
  run script -q /dev/null "$NK" greet --art fakeart2 < /dev/null
  [ "$(cat "$HOME/.cache/nekoshell/art-name")" = "Fake Art · two" ]
  run "$NK" greet --art nothere
  [ "$status" -eq 1 ]
  assert_contains "$output" "nothere is not an enabled art provider"
  run "$NK" greet --art
  [ "$status" -eq 2 ]
}

@test "nekoshell art lists, adds and copies the samples" {
  "$NK" plugin add greet >/dev/null
  run "$NK" art list
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run "$NK" art add "$P/art/ghost.png"
  [ "$status" -eq 0 ]
  run "$NK" art list
  [ "$output" = "ghost.png" ]
  run "$NK" art sample
  [ "$status" -eq 0 ]
  run "$NK" art list
  assert_contains "$output" "neko.png"
  assert_contains "$output" "slime.png"
}

@test "nekoshell art add refuses a file that is not there" {
  "$NK" plugin add greet >/dev/null
  run "$NK" art add "$HOME/nope.png"
  [ "$status" -ne 0 ]
}

# --- late.zsh ---------------------------------------------------------------

@test "late.zsh greets an interactive shell that owns a tty" {
  mkdir -p "$HOME/bin"
  printf '#!/usr/bin/env bash\necho GREETED\n' > "$HOME/bin/nekoshell-greet"
  chmod +x "$HOME/bin/nekoshell-greet"
  run script -q /dev/null zsh -o NO_GLOBAL_RCS -ic "PATH='$HOME/bin:/usr/bin:/bin'; source '$P/late.zsh'" < /dev/null
  assert_contains "$output" "GREETED"
}

@test "late.zsh says nothing in a non-interactive shell or over ssh" {
  mkdir -p "$HOME/bin"
  printf '#!/usr/bin/env bash\necho GREETED\n' > "$HOME/bin/nekoshell-greet"
  chmod +x "$HOME/bin/nekoshell-greet"
  run zsh -o NO_GLOBAL_RCS -c "PATH='$HOME/bin:/usr/bin:/bin'; source '$P/late.zsh'; echo DONE"
  assert_contains "$output" "DONE"
  assert_not_contains "$output" "GREETED"
  SSH_CONNECTION="1 2 3 4" run script -q /dev/null zsh -o NO_GLOBAL_RCS -ic "PATH='$HOME/bin:/usr/bin:/bin'; source '$P/late.zsh'" < /dev/null
  assert_not_contains "$output" "GREETED"
  SSH_CONNECTION="1 2 3 4" NEKOSHELL_GREET_SSH=1 run script -q /dev/null zsh -o NO_GLOBAL_RCS -ic "PATH='$HOME/bin:/usr/bin:/bin'; source '$P/late.zsh'" < /dev/null
  assert_contains "$output" "GREETED"
}

@test "late.zsh is silent when the greeting is not installed" {
  run script -q /dev/null zsh -o NO_GLOBAL_RCS -ic "PATH=/nonexistent; source '$P/late.zsh'; echo DONE" < /dev/null
  assert_contains "$output" "DONE"
  assert_not_contains "$output" "command not found"
}

# --- doctor -----------------------------------------------------------------

@test "doctor reports fastfetch, one row per enabled provider and the greet budget" {
  "$NK" plugin add greet >/dev/null
  set_plugins '"greet", "fakeart", "fakeart2"'
  run "$NK" doctor --plugin greet
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +tool: fastfetch'
  assert_matches "$output" 'ok +art: fakeart +draws'
  assert_matches "$output" 'ok +art: fakeart2 +draws'
  assert_matches "$output" 'greet time +[0-9]+ ms'
  assert_not_contains "$output" "could not measure"
  FAKEART_FAIL=1 run "$NK" doctor --plugin greet
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +art: fakeart +nothing to draw \(nekoshell plugin add fakeart\)'
}

@test "doctor warns when no provider is enabled" {
  "$NK" plugin add greet >/dev/null
  set_plugins '"greet"'
  run "$NK" doctor --plugin greet
  [ "$status" -eq 0 ]
  assert_matches "$output" 'warn +art +no art provider enabled \(run: nekoshell plugin add pokemon\)'
}

# The doctor is run from a real shell, and that shell may be over SSH, inside
# tmux, or inside the panel — each of which silences the greeting. The probe
# has to clear all of them, or the row measures where the doctor was run from
# instead of how long the greeting takes.
@test "doctor measures the greet time from a silenced shell" {
  "$NK" plugin add greet >/dev/null
  for env_var in SSH_CONNECTION=1 NEKOSHELL_PANEL=1 TMUX=/tmp/x CLAUDECODE=1 NEKOSHELL_GREET_MODE=text; do
    run env "$env_var" "$NK" doctor --plugin greet
    [ "$status" -eq 0 ]
    assert_matches "$output" "ok +greet time +[0-9]+ ms"
  done
}

@test "doctor fails a missing fastfetch" {
  "$NK" plugin add greet >/dev/null
  run env PATH="/usr/bin:/bin" "$NK" doctor --plugin greet
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +tool: fastfetch'
}

@test "remove drops the plugin and leaves your greet.conf and art alone" {
  set_plugins ''
  "$NK" plugin add greet >/dev/null
  run "$NK" plugin remove greet
  [ "$status" -eq 0 ]
  [ -f "$HOME/.config/nekoshell/greet.conf" ]
  [ "$(grep '^plugins' "$HOME/.config/nekoshell/nekoshell.toml")" = 'plugins = []' ]
}

@test "the sample art files are valid PNGs" {
  for f in neko ghost slime; do
    run python3 -c "d=open('$P/art/$f.png','rb').read(8); print(d==b'\x89PNG\r\n\x1a\n')"
    [ "$output" = "True" ]
  done
}
