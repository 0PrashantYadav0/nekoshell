#!/usr/bin/env bats
load ../helpers

# The greeting: a Pokémon or a picture from your art pack, next to the machine
# stats fastfetch prints. It runs on every new interactive shell, so the whole
# thing is built around never costing anything and never failing one: every
# problem exits 0 quietly.

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  unset CLAUDECODE TMUX NEKOSHELL_PANEL SSH_CONNECTION NEKOSHELL_NO_GREET NEKOSHELL_GREET_SSH NEKOSHELL_GREET_MODE
  # A developer running the tests from a nekoshell shell has NEKOSHELL_ROOT
  # exported, pointing at their own checkout. The greeting prefers it over the
  # recorded root, so it has to go: these tests are about this checkout, and
  # the run below is what proves the recorded root is found without it.
  unset NEKOSHELL_ROOT
  mkdir -p "$HOME/.config/nekoshell/art" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
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

@test "add installs fastfetch, copies greet.conf and renders the fastfetch config" {
  run "$NK" plugin add greet
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install fastfetch"
  [ -f "$HOME/.config/nekoshell/greet.conf" ]
  [ ! -L "$HOME/.config/nekoshell/greet.conf" ]
  grep -q 'POKEMON_SHARE' "$HOME/.config/nekoshell/greet.conf"
  [ -f "$HOME/.config/fastfetch/config.jsonc" ]
  [ ! -L "$HOME/.config/fastfetch/config.jsonc" ]
}

@test "add clones pokemon-colorscripts at the pinned commit and links it onto PATH" {
  sha="$(sed -n 's/^POKEMON_SHA="\([0-9a-f]*\)".*/\1/p' "$P/install.sh")"
  printf '%s\n' "$sha" | grep -q '^[0-9a-f]\{40\}$'
  run "$NK" plugin add greet
  [ "$status" -eq 0 ]
  [ -d "$HOME/.local/share/pokemon-colorscripts" ]
  [ -L "$HOME/.local/bin/pokemon-colorscripts" ]
  assert_contains "$output" "$sha"
}

@test "a second add does not clone pokemon-colorscripts again" {
  "$NK" plugin add greet >/dev/null
  run "$NK" plugin add greet
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "clone --quiet https://gitlab.com/phoneybadger/pokemon-colorscripts.git"
  [ -L "$HOME/.local/bin/pokemon-colorscripts" ]
}

@test "greet.conf is yours: a second add keeps your edit" {
  "$NK" plugin add greet >/dev/null
  printf 'POKEMON_SHARE=5\n' >> "$HOME/.config/nekoshell/greet.conf"
  "$NK" plugin add greet >/dev/null
  grep -q 'POKEMON_SHARE=5' "$HOME/.config/nekoshell/greet.conf"
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
  command -v fastfetch >/dev/null || skip "fastfetch not installed"
  "$NK" plugin add greet >/dev/null
  run env PATH="/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin" \
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

@test "silent when stdout is not a tty" {
  "$NK" plugin add greet >/dev/null
  run "$P/bin/nekoshell-greet"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "prints nothing when fastfetch is missing" {
  "$NK" plugin add greet >/dev/null
  PATH="/usr/bin:/bin" NEKOSHELL_SEED=1 run greet
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the pokemon path pipes the sprite into fastfetch and caches the name" {
  "$NK" plugin add greet >/dev/null
  NEKOSHELL_SEED=1 run greet
  [ "$status" -eq 0 ]
  assert_contains "$output" "--file-raw - stdin=3"
  [ "$(cat "$HOME/.cache/nekoshell/art-name")" = "Pikachu · #025 · Electric · Gen 1" ]
}

@test "shiny odds of 1 always passes -s" {
  "$NK" plugin add greet >/dev/null
  echo 'SHINY_ODDS=1' > "$HOME/.config/nekoshell/greet.conf"
  NEKOSHELL_SEED=1 run greet
  [ "$(cat "$HOME/.cache/nekoshell/art-name")" = "Pikachu · #025 · Electric · Gen 1 ✦ shiny" ]
}

# The image branch is a question about the terminal, not about TERM_PROGRAM: it
# is taken only when the adapter says it can draw images. The `fake` fixture
# can; `bare` (the contract's own defaults) cannot.
@test "the image branch is taken on a terminal whose capabilities include images" {
  "$NK" plugin add greet >/dev/null
  cp "$P/art/neko.png" "$HOME/.config/nekoshell/art/"
  echo 'POKEMON_SHARE=0' > "$HOME/.config/nekoshell/greet.conf"
  NEKOSHELL_SEED=1 run greet
  assert_contains "$output" "--kitty $HOME/.config/nekoshell/art/neko.png --logo-width 28 --logo-height 14"
  [ "$(cat "$HOME/.cache/nekoshell/art-name")" = "neko.png" ]
}

@test "a terminal that cannot draw images falls back to the pokemon" {
  "$NK" plugin add greet >/dev/null
  cp "$P/art/neko.png" "$HOME/.config/nekoshell/art/"
  echo 'POKEMON_SHARE=0' > "$HOME/.config/nekoshell/greet.conf"
  set_terminal bare
  NEKOSHELL_SEED=1 run greet
  assert_contains "$output" "--file-raw -"
  assert_not_contains "$output" "--kitty"
  assert_not_contains "$output" "--iterm"
}

# iTerm2 draws its own inline images with a protocol of its own; everything
# else that can draw images speaks kitty's.
@test "an image-capable iterm2 gets --iterm rather than --kitty" {
  "$NK" plugin add greet >/dev/null
  cp "$P/art/neko.png" "$HOME/.config/nekoshell/art/"
  echo 'POKEMON_SHARE=0' > "$HOME/.config/nekoshell/greet.conf"
  mkdir -p "$HOME/terms/iterm2"
  printf 'terminal_name() { echo iterm2; }\nterminal_capabilities() { echo "truecolor images"; }\n' \
    > "$HOME/terms/iterm2/adapter.sh"
  set_terminal iterm2
  NEKOSHELL_TERMINALS_DIR="$HOME/terms" NEKOSHELL_SEED=1 run greet
  assert_contains "$output" "--iterm $HOME/.config/nekoshell/art/neko.png"
}

@test "falls back to the pokemon when the art pack is empty" {
  "$NK" plugin add greet >/dev/null
  echo 'POKEMON_SHARE=0' > "$HOME/.config/nekoshell/greet.conf"
  NEKOSHELL_SEED=1 run greet
  assert_contains "$output" "--file-raw -"
}

@test "NEKOSHELL_GREET_MODE forces either branch" {
  "$NK" plugin add greet >/dev/null
  cp "$P/art/neko.png" "$HOME/.config/nekoshell/art/"
  # share 100 means the roll can never choose the image on its own
  echo 'POKEMON_SHARE=100' > "$HOME/.config/nekoshell/greet.conf"
  NEKOSHELL_GREET_MODE=image NEKOSHELL_SEED=1 run greet
  assert_contains "$output" "--kitty"
  echo 'POKEMON_SHARE=0' > "$HOME/.config/nekoshell/greet.conf"
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

@test "nekoshell greet --text and --image reach the two branches" {
  "$NK" plugin add greet >/dev/null
  cp "$P/art/neko.png" "$HOME/.config/nekoshell/art/"
  echo 'POKEMON_SHARE=100' > "$HOME/.config/nekoshell/greet.conf"
  run script -q /dev/null "$NK" greet --image < /dev/null
  assert_contains "$output" "--kitty"
  echo 'POKEMON_SHARE=0' > "$HOME/.config/nekoshell/greet.conf"
  run script -q /dev/null "$NK" greet --text < /dev/null
  assert_contains "$output" "--file-raw -"
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

@test "doctor reports fastfetch, pokemon-colorscripts and the greet budget" {
  "$NK" plugin add greet >/dev/null
  run "$NK" doctor --plugin greet
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +tool: fastfetch'
  assert_matches "$output" 'ok +pokemon-colorscripts'
  assert_matches "$output" 'greet time +[0-9]+ ms'
  assert_not_contains "$output" "could not measure"
}

@test "doctor fails a missing fastfetch" {
  "$NK" plugin add greet >/dev/null
  run env PATH="/usr/bin:/bin" "$NK" doctor --plugin greet
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +tool: fastfetch'
}

@test "remove drops the plugin and leaves your greet.conf and art alone" {
  "$NK" plugin add greet >/dev/null
  run "$NK" plugin remove greet
  [ "$status" -eq 0 ]
  [ -f "$HOME/.config/nekoshell/greet.conf" ]
  [ "$(grep '^plugins' "$HOME/.config/nekoshell/nekoshell.toml")" = 'plugins = []' ]
}

@test "pokemon.tsv has the header and well-known rows" {
  run head -1 "$P/data/pokemon.tsv"
  [ "$output" = $'name\tdex\ttypes\tgen\theight_m\tweight_kg' ]
  run awk -F'\t' '$1=="pikachu"{print $2, $3, $4}' "$P/data/pokemon.tsv"
  [ "$output" = "25 Electric 1" ]
  run awk -F'\t' '$1=="bulbasaur"{print $2, $3, $4}' "$P/data/pokemon.tsv"
  [ "$output" = "1 Grass/Poison 1" ]
  run awk -F'\t' '$1=="mr-mime"{print $2}' "$P/data/pokemon.tsv"
  [ "$output" = "122" ]
  run bash -c "wc -l < '$P/data/pokemon.tsv' | tr -d ' '"
  [ "$output" -gt 900 ]
}

@test "pokemon_facts formats a known and an unknown name" {
  # Extract via a temp file rather than `source <(...)`: on this machine's
  # bash 3.2.57, sourcing a process substitution from inside `bash -c`
  # silently reads zero bytes, so the function never gets defined.
  run bash -c "
    tmpf=\$(mktemp)
    sed -n '/^pokemon_facts()/,/^}/p' '$P/bin/nekoshell-greet' > \"\$tmpf\"
    PLUGIN_DIR='$P'
    source \"\$tmpf\"
    rm -f \"\$tmpf\"
    pokemon_facts pikachu
    pokemon_facts missingno
  "
  [ "${lines[0]}" = "Pikachu · #025 · Electric · Gen 1" ]
  [ "${lines[1]}" = "Missingno" ]
}

@test "the sample art files are valid PNGs" {
  for f in neko ghost slime; do
    run python3 -c "d=open('$P/art/$f.png','rb').read(8); print(d==b'\x89PNG\r\n\x1a\n')"
    [ "$output" = "True" ]
  done
}
