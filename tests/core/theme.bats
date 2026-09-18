#!/usr/bin/env bats
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  # theme is "auto", not a fixed flavour: theme_resolve only ever consults
  # macOS appearance when the setting is "auto" (a fixed flavour is returned
  # as-is, on purpose — it must not be silently overridden by dark mode), and
  # the direct theme_resolve test below exercises exactly that appearance
  # following.
  printf 'root = "%s"\nterminal = "fake"\ntheme = "auto"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  export NEKOSHELL_ROOT="$REPO_ROOT"
  for l in paths log backup config link brew terminal plugin theme; do source "$REPO_ROOT/core/lib/$l.sh"; done
}
teardown() { teardown_tmp_home; }

# log.sh (sourced in setup) defines its own run(), which shadows bats' run()
# for the rest of this test process (subprocess invocations through "$NK"
# included, since the shadow is a name lookup in this process, not in the
# child). Plain command substitution captures stdout+stderr and exit status
# instead, throughout this file.

@test "palettes has four flavours and 42 roles" {
  [ "$(theme_flavors | tr '\n' ' ')" = "frappe latte macchiato mocha " ]
  [ "$(theme_hexes mocha base mauve | tr '\n' ' ')" = "1e1e2e cba6f7 " ]
  for flavor in frappe latte macchiato mocha; do
    [ "$(python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))[sys.argv[2]]))" "$REPO_ROOT/core/theme/palettes.json" "$flavor")" = "42" ]
  done
}
@test "the ansi roles are per flavour: black is dark on latte and light on mocha" {
  # Upstream's ansiColors: latte draws black as subtext1, the dark flavours as
  # surface1, and every flavour has its own bright shades.
  [ "$(theme_hexes latte ansiblack ansibrblack ansiwhite ansibrwhite | tr '\n' ' ')" = "5c5f77 6c6f85 acb0be bcc0cc " ]
  [ "$(theme_hexes mocha ansiblack ansibrblack ansiwhite ansibrwhite | tr '\n' ' ')" = "45475a 585b70 a6adc8 bac2de " ]
  [ "$(theme_hexes mocha ansired ansibrred | tr '\n' ' ')" = "f38ba8 f37799 " ]
}
@test "theme_render_template substitutes every placeholder kind" {
  printf '%s\n' '@@FLAVOR@@ @@TITLE@@ @@hex:mauve@@ @@HEX:mauve@@ @@sgr:mauve@@ @@rgb:mauve@@' > "$HOME/t.tmpl"
  theme_render_template "$HOME/t.tmpl" "$HOME/out" mocha
  [ "$(cat "$HOME/out")" = "mocha Mocha cba6f7 #cba6f7 38;2;203;166;247 203,166,247" ]
}
@test "theme_resolve follows macOS appearance with configurable pair" {
  export FAKE_DEFAULTS_APPEARANCE=Dark
  status=0; output="$(theme_resolve 2>&1)" || status=$?
  [ "$output" = "mocha" ]
  export FAKE_DEFAULTS_APPEARANCE=
  status=0; output="$(theme_resolve 2>&1)" || status=$?
  [ "$output" = "latte" ]
  config_set theme_auto_dark macchiato
  export FAKE_DEFAULTS_APPEARANCE=Dark
  status=0; output="$(theme_resolve 2>&1)" || status=$?
  [ "$output" = "macchiato" ]
}
@test "nekoshell theme <flavour> renders starship, theme.zsh, calls the adapter and plugin hooks" {
  "$NK" plugin add demo >/dev/null
  status=0; output="$("$NK" theme latte 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  grep -q '^palette = "catppuccin_latte"' "$HOME/.config/starship.toml"
  grep -q 'BAT_THEME="Catppuccin Latte"' "$HOME/.config/nekoshell/theme.zsh"
  grep -q 'fake apply latte' "$HOME/.cache/nekoshell/hooks.log"
  [ "$(config_get theme)" = "latte" ]; [ "$(config_get theme_resolved)" = "latte" ]
  status=0; output="$("$NK" theme current 2>&1)" || status=$?
  [ "$output" = "latte" ]
}
@test "nekoshell theme auto records auto and resolves" {
  export FAKE_DEFAULTS_APPEARANCE=Dark
  status=0; output="$("$NK" theme auto 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(config_get theme)" = "auto" ]; [ "$(config_get theme_resolved)" = "mocha" ]
  export FAKE_DEFAULTS_APPEARANCE=
  status=0; output="$("$NK" theme --resolve 2>&1)" || status=$?
  [ "$(config_get theme_resolved)" = "latte" ]
}
@test "unknown flavour fails" {
  status=0; output="$("$NK" theme neon 2>&1)" || status=$?
  [ "$status" -eq 1 ]
}
@test "starship validates every rendered flavour" {
  command -v starship >/dev/null || skip "starship not installed"
  for f in latte frappe macchiato mocha; do
    theme_render_template "$REPO_ROOT/core/starship/starship.toml.tmpl" "$HOME/s-$f.toml" "$f"
    STARSHIP_CONFIG="$HOME/s-$f.toml" starship print-config >/dev/null
  done
}

# theme_apply renders and records straight to disk - none of it goes through
# run() - so the dry-run gate has to be in theme_apply itself.
@test "a dry-run theme switch renders nothing and records nothing" {
  local st=0 out=""
  out="$(NEKOSHELL_DRY_RUN=1 "$NK" theme latte 2>&1)" || st=$?
  [ "$st" -eq 0 ]
  assert_contains "$out" "would render latte"
  [ "$(config_get theme_resolved)" = "mocha" ]
  [ "$(config_get theme)" = "auto" ]
  [ ! -e "$HOME/.config/starship.toml" ]
  [ ! -e "$NEKOSHELL_CONFIG/theme.zsh" ]
}
