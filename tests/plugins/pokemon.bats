#!/usr/bin/env bats
# The pokemon art provider: pokemon-colorscripts, pinned, and a greet-art that
# captions the sprite with the Pokédex facts.
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  unset FAKE_GIT_HAS_COMMIT FAKE_GIT_FAIL_FETCH FAKE_GIT_NOT_REPO NEKOSHELL_SEED SHINY_ODDS POKEMON_SHINY_ODDS
  unset CLAUDECODE TMUX NEKOSHELL_PANEL SSH_CONNECTION NEKOSHELL_GREET_MODE NEKOSHELL_GREET_ART
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/pokemon"
  export PLUGIN_DIR="$P" PLUGIN_NAME=pokemon
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

@test "add enables greet first, clones pokemon-colorscripts at the pinned commit and links it onto PATH" {
  sha="$(sed -n 's/^POKEMON_SHA="\([0-9a-f]*\)".*/\1/p' "$P/install.sh")"
  printf '%s\n' "$sha" | grep -q '^[0-9a-f]\{40\}$'
  run "$NK" plugin add pokemon
  [ "$status" -eq 0 ]
  assert_contains "$output" "pokemon needs greet; adding it first"
  assert_contains "$output" "git clone --quiet https://gitlab.com/phoneybadger/pokemon-colorscripts.git $HOME/.local/share/pokemon-colorscripts"
  assert_contains "$output" "checkout --quiet $sha"
  [ -L "$HOME/.local/bin/pokemon-colorscripts" ]
  [ "$(grep '^plugins' "$HOME/.config/nekoshell/nekoshell.toml")" = 'plugins = ["greet", "pokemon"]' ]
}

@test "a second add does not clone again" {
  "$NK" plugin add pokemon >/dev/null
  run "$NK" plugin add pokemon
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "clone --quiet"
  assert_contains "$output" "git -C $HOME/.local/share/pokemon-colorscripts fetch --quiet"
  [ -L "$HOME/.local/bin/pokemon-colorscripts" ]
}

@test "a checkout that already holds the pinned commit is not fetched" {
  "$NK" plugin add pokemon >/dev/null
  run env FAKE_GIT_HAS_COMMIT=1 "$NK" plugin add pokemon
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "fetch --quiet"
  assert_contains "$output" "checkout --quiet 5802ff6"
}

# Offline is not broken: an older set of sprites is still a greeting.
@test "a fetch that fails warns and the add still succeeds" {
  "$NK" plugin add pokemon >/dev/null
  run env FAKE_GIT_FAIL_FETCH=1 "$NK" plugin add pokemon
  [ "$status" -eq 0 ]
  assert_contains "$output" "pokemon: could not fetch pokemon-colorscripts; keeping what is there"
  assert_contains "$output" "pokemon enabled"
}

# A directory that is there but is not a checkout fails every git command that
# reaches into it — the probe, the fetch and the checkout — and has no script
# to make executable either. All four are notes: the greeting drops the sprite
# and everything else about the plugin still works.
@test "a pokemon directory that is not a checkout warns and the add still succeeds" {
  mkdir -p "$HOME/.local/share/pokemon-colorscripts"
  echo 'not a checkout' > "$HOME/.local/share/pokemon-colorscripts/notes.txt"
  run env FAKE_GIT_NOT_REPO=1 "$NK" plugin add pokemon
  [ "$status" -eq 0 ]
  assert_contains "$output" "pokemon: could not fetch pokemon-colorscripts; keeping what is there"
  assert_contains "$output" "pokemon: could not check out pokemon-colorscripts at"
  assert_contains "$output" "pokemon: pokemon-colorscripts.py is missing"
  assert_contains "$output" "pokemon enabled"
  assert_not_contains "$output" "clone --quiet"
  [ "$(cat "$HOME/.local/share/pokemon-colorscripts/notes.txt")" = "not a checkout" ]
}

@test "greet-art prints the facts caption and then the sprite" {
  run "$P/greet-art"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Pikachu · #025 · Electric · Gen 1" ]
  [ "${#lines[@]}" -eq 4 ]
}

@test "greet-art is silent and non-zero without pokemon-colorscripts" {
  PATH="/usr/bin:/bin" run "$P/greet-art"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "shiny odds of 1 always passes -s, and the old SHINY_ODDS key still works" {
  POKEMON_SHINY_ODDS=1 run "$P/greet-art"
  [ "${lines[0]}" = "Pikachu · #025 · Electric · Gen 1 ✦ shiny" ]
  SHINY_ODDS=1 run "$P/greet-art"
  assert_contains "${lines[0]}" "✦ shiny"
  POKEMON_SHINY_ODDS=0 run "$P/greet-art"
  assert_not_contains "${lines[0]}" "shiny"
}

@test "an unknown name is capitalised on its own" {
  mkdir -p "$HOME/bin"
  printf '#!/usr/bin/env bash\necho missingno\necho art\n' > "$HOME/bin/pokemon-colorscripts"
  chmod +x "$HOME/bin/pokemon-colorscripts"
  # Shiny odds off: the roll is 1 in 128, and a lucky one would append " ✦ shiny".
  POKEMON_SHINY_ODDS=0 PATH="$HOME/bin:$PATH" run "$P/greet-art"
  [ "${lines[0]}" = "Missingno" ]
}

@test "the greeting draws the pokémon through the provider" {
  "$NK" plugin add pokemon >/dev/null
  run script -q /dev/null "$NK" greet --art pokemon < /dev/null
  assert_contains "$output" "--file-raw - stdin=3"
  [ "$(cat "$HOME/.cache/nekoshell/art-name")" = "Pikachu · #025 · Electric · Gen 1" ]
}

@test "doctor reports pokemon-colorscripts" {
  "$NK" plugin add pokemon >/dev/null
  run "$NK" doctor --plugin pokemon
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +pokemon-colorscripts'
  run env PATH="/usr/bin:/bin" "$NK" doctor --plugin pokemon
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +pokemon-colorscripts +missing or broken'
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

@test "every profile enables pokemon right after greet" {
  for p in minimal dev full; do
    grep -A1 '^greet$' "$REPO_ROOT/profiles/$p.txt" | grep -qx pokemon
  done
}
