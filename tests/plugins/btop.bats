#!/usr/bin/env bats
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/btop"
}
teardown() { teardown_tmp_home; }

marker() { printf '%s\n' "$output" | sed -n "s/^$1=//p"; }

# set_flavour FLAVOUR: what a theme switch records, without rendering the rest.
set_flavour() {
  sed "s/^theme_resolved = .*/theme_resolved = \"$1\"/" "$HOME/.config/nekoshell/nekoshell.toml" > "$HOME/t.toml"
  mv "$HOME/t.toml" "$HOME/.config/nekoshell/nekoshell.toml"
}

@test "plugin.toml is complete and the README has its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
}

@test "add installs btop and links all four themes" {
  run "$NK" plugin add btop
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install btop"
  for f in frappe latte macchiato mocha; do
    [ -L "$HOME/.config/btop/themes/catppuccin_$f.theme" ]
  done
}

@test "the theme hook points btop at the current flavour" {
  "$NK" plugin add btop >/dev/null
  grep -q 'color_theme = "catppuccin_mocha"' "$HOME/.config/btop/btop.conf"
}

@test "a flavour switch rewrites only the color_theme line" {
  "$NK" plugin add btop >/dev/null
  printf 'update_ms = 500\n' >> "$HOME/.config/btop/btop.conf"
  set_flavour latte
  "$NK" plugin add btop >/dev/null
  grep -q 'color_theme = "catppuccin_latte"' "$HOME/.config/btop/btop.conf"
  [ "$(grep -c 'color_theme' "$HOME/.config/btop/btop.conf")" -eq 1 ]
  grep -q 'update_ms = 500' "$HOME/.config/btop/btop.conf"
}

@test "an existing btop.conf without a color_theme line gets one appended" {
  mkdir -p "$HOME/.config/btop"
  printf '#? Config file for btop\nupdate_ms = 1000\n' > "$HOME/.config/btop/btop.conf"
  "$NK" plugin add btop >/dev/null
  grep -q 'update_ms = 1000' "$HOME/.config/btop/btop.conf"
  grep -q 'color_theme = "catppuccin_mocha"' "$HOME/.config/btop/btop.conf"
}

@test "doctor reports btop as a tool and the theme it is pointed at" {
  "$NK" plugin add btop >/dev/null
  run "$NK" doctor --plugin btop
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +tool: btop'
  assert_matches "$output" 'ok +btop theme +catppuccin_mocha'
}

@test "doctor warns when btop.conf names another theme" {
  "$NK" plugin add btop >/dev/null
  sed 's/^color_theme.*/color_theme = "Default"/' "$HOME/.config/btop/btop.conf" > "$HOME/b.conf"
  mv "$HOME/b.conf" "$HOME/.config/btop/btop.conf"
  run "$NK" doctor --plugin btop
  [ "$status" -eq 0 ]
  assert_matches "$output" 'warn +btop theme'
}

@test "remove unlinks the themes and leaves btop.conf alone" {
  "$NK" plugin add btop >/dev/null
  run "$NK" plugin remove btop
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.config/btop/themes/catppuccin_mocha.theme" ]
  [ -f "$HOME/.config/btop/btop.conf" ]
  [ "$(grep '^plugins' "$HOME/.config/nekoshell/nekoshell.toml")" = 'plugins = []' ]
}

@test "plugin.zsh aliases top" {
  run zsh -o NO_GLOBAL_RCS -ic "source '$P/plugin.zsh'; echo \"TOP=\$(alias top)\""
  [ "$status" -eq 0 ]
  assert_contains "$(marker TOP)" "btop"
}

@test "plugin.zsh is silent when btop is not installed" {
  run zsh -o NO_GLOBAL_RCS -ic "PATH=/nonexistent; source '$P/plugin.zsh'; alias top >/dev/null 2>&1 && echo HAS_TOP; echo DONE"
  [ "$status" -eq 0 ]
  assert_contains "$output" "DONE"
  assert_not_contains "$output" "HAS_TOP"
  assert_not_contains "$output" "command not found"
}
