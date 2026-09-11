#!/usr/bin/env bats
load helpers

@test "pokemon.tsv has the header and well-known rows" {
  run head -1 "$REPO_ROOT/data/pokemon.tsv"
  [ "$output" = $'name\tdex\ttypes\tgen\theight_m\tweight_kg' ]
  run awk -F'\t' '$1=="pikachu"{print $2, $3, $4}' "$REPO_ROOT/data/pokemon.tsv"
  [ "$output" = "25 Electric 1" ]
  run awk -F'\t' '$1=="bulbasaur"{print $2, $3, $4}' "$REPO_ROOT/data/pokemon.tsv"
  [ "$output" = "1 Grass/Poison 1" ]
  run awk -F'\t' '$1=="mr-mime"{print $2}' "$REPO_ROOT/data/pokemon.tsv"
  [ "$output" = "122" ]
  run bash -c "wc -l < '$REPO_ROOT/data/pokemon.tsv' | tr -d ' '"
  [ "$output" -gt 900 ]
}

@test "pokemon_facts formats a known and an unknown name" {
  # Extract via a temp file rather than `source <(...)`: on this machine's
  # bash 3.2.57, sourcing a process substitution from inside `bash -c`
  # silently reads zero bytes (a known bash 3.2 timing quirk), so the
  # function never gets defined even though the extraction itself is fine.
  run bash -c "
    tmpf=\$(mktemp)
    sed -n '/^pokemon_facts()/,/^}/p' '$REPO_ROOT/bin/nekoshell-greet' > \"\$tmpf\"
    NEKOSHELL_ROOT='$REPO_ROOT'
    source \"\$tmpf\"
    rm -f \"\$tmpf\"
    pokemon_facts pikachu
    pokemon_facts missingno
  "
  [ "${lines[0]}" = "Pikachu · #025 · Electric · Gen 1" ]
  [ "${lines[1]}" = "Missingno" ]
}
