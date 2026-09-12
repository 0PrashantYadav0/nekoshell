#!/usr/bin/env bats
load ../helpers

setup() {
  setup_tmp_home
  export NEKOSHELL_ROOT="$REPO_ROOT"
  source "$REPO_ROOT/core/lib/paths.sh"
  source "$REPO_ROOT/core/lib/config.sh"
  T="$HOME/t.toml"
  cat > "$T" <<'EOF'
# comment
root = "/Users/me/.nekoshell"
theme = "auto"
theme_resolved = "mocha"
plugins = ["greet", "modern-cli", "spotify"]
empty = []
count = 3
EOF
}
teardown() { teardown_tmp_home; }

@test "toml_get reads a quoted string" {
  run toml_get "$T" root; [ "$status" -eq 0 ]; [ "$output" = "/Users/me/.nekoshell" ]
}
@test "toml_get does not confuse theme with theme_resolved" {
  run toml_get "$T" theme; [ "$output" = "auto" ]
  run toml_get "$T" theme_resolved; [ "$output" = "mocha" ]
}
@test "toml_get reads a bare value and fails on a missing key" {
  run toml_get "$T" count; [ "$output" = "3" ]
  run toml_get "$T" nope; [ "$status" -eq 1 ]; [ -z "$output" ]
}
@test "toml_get keeps a # inside quotes" {
  echo 'accent = "#cba6f7"' >> "$T"
  run toml_get "$T" accent; [ "$output" = "#cba6f7" ]
}
@test "toml_list prints items one per line, empty list prints nothing" {
  run toml_list "$T" plugins; [ "$output" = $'greet\nmodern-cli\nspotify' ]
  run toml_list "$T" empty; [ -z "$output" ]; [ "$status" -eq 0 ]
}
@test "toml_set replaces in place and appends when missing" {
  toml_set "$T" theme mocha
  [ "$(grep -c '^theme = ' "$T")" -eq 1 ]
  [ "$(toml_get "$T" theme)" = "mocha" ]
  toml_set "$T" terminal kitty
  [ "$(toml_get "$T" terminal)" = "kitty" ]
  [ "$(tail -1 "$T")" = 'terminal = "kitty"' ]
}
@test "toml_set creates the file and its directory" {
  toml_set "$HOME/deep/dir/new.toml" a b
  [ "$(toml_get "$HOME/deep/dir/new.toml" a)" = "b" ]
}
@test "toml_set_list writes a one-line array" {
  toml_set_list "$T" plugins a b
  grep -q '^plugins = \["a", "b"\]$' "$T"
  toml_set_list "$T" plugins
  grep -q '^plugins = \[\]$' "$T"
}
@test "config_* wrap NEKOSHELL_TOML" {
  export NEKOSHELL_TOML="$T"
  [ "$(config_get theme)" = "auto" ]
  config_set theme latte; [ "$(config_get theme)" = "latte" ]
  config_list_add plugins fzf; config_list_add plugins fzf
  [ "$(config_list plugins | tr '\n' ' ')" = "greet modern-cli spotify fzf " ]
  config_list_remove plugins modern-cli
  [ "$(config_list plugins | tr '\n' ' ')" = "greet spotify fzf " ]
  config_has theme; ! config_has nope
}
