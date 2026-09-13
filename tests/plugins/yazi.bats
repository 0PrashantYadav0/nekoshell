#!/usr/bin/env bats
# The yazi plugin: a rendered theme, a copied-once config, and y.
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  unset ZDOTDIR FAKE_YAZI_CWD
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/yazi"
  THEME="$HOME/.config/yazi/theme.toml"
}
teardown() { teardown_tmp_home; }

@test "plugin.toml is complete and the README has its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags copy_guard; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
}

@test "the template carries no literal colour: every one is a palette role" {
  run grep -c '#[0-9a-fA-F]\{6\}' "$P/files/theme.toml.tmpl"
  [ "$output" = "0" ]
  [ "$(grep -c '@@HEX:' "$P/files/theme.toml.tmpl")" -gt 50 ]
}

@test "add installs yazi, copies yazi.toml once and renders the theme" {
  run "$NK" plugin add yazi
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install yazi"
  [ -f "$HOME/.config/yazi/yazi.toml" ]
  [ ! -L "$HOME/.config/yazi/yazi.toml" ]
  head -1 "$THEME" | grep -q nekoshell
  grep -q 'cwd = { fg = "#94e2d5" }' "$THEME"
  grep -q 'Mocha' "$THEME"
  ! grep -q '@@' "$THEME"
}

@test "an existing yazi.toml is left alone" {
  mkdir -p "$HOME/.config/yazi"
  echo mine > "$HOME/.config/yazi/yazi.toml"
  run "$NK" plugin add yazi
  [ "$status" -eq 0 ]
  assert_contains "$output" ".config/yazi/yazi.toml exists; left your config alone"
  [ "$(cat "$HOME/.config/yazi/yazi.toml")" = mine ]
}

@test "a theme switch re-renders theme.toml, and a theme of your own is backed up first" {
  mkdir -p "$HOME/.config/yazi"
  echo mine > "$THEME"
  "$NK" plugin add yazi >/dev/null
  [ -n "$(find "$HOME/.local/share/nekoshell/backup" -name theme.toml)" ]
  grep -q 'cwd = { fg = "#94e2d5" }' "$THEME"
  run "$NK" theme latte
  [ "$status" -eq 0 ]
  grep -q 'cwd = { fg = "#179299" }' "$THEME"
  grep -q 'Latte' "$THEME"
}

@test "y changes directory to where yazi quit" {
  "$NK" plugin add yazi >/dev/null
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  mkdir -p "$HOME/there"
  run zsh -o NO_GLOBAL_RCS -ic 'cd "$HOME"; FAKE_YAZI_CWD="$HOME/there" y; pwd; exit 0'
  [ "$status" -eq 0 ]
  assert_contains "$output" "yazi --cwd-file="
  [ "${lines[${#lines[@]}-1]}" = "$HOME/there" ]
}

@test "without yazi the shell defines no y" {
  "$NK" plugin add yazi >/dev/null
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  run env PATH="/usr/bin:/bin" zsh -o NO_GLOBAL_RCS -ic '(( $+functions[y] )) && echo Y-DEFINED; echo DONE; exit 0'
  assert_contains "$output" "DONE"
  assert_not_contains "$output" "Y-DEFINED"
}

@test "doctor reports yazi and the rendered theme" {
  "$NK" plugin add yazi >/dev/null
  run "$NK" doctor --plugin yazi
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +tool: yazi'
  assert_matches "$output" 'ok +yazi theme +mocha'
  rm "$THEME"
  run "$NK" doctor --plugin yazi
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +yazi theme +not rendered for mocha'
}

@test "remove drops the rendered theme, keeps yazi.toml and a theme of your own" {
  "$NK" plugin add yazi >/dev/null
  run "$NK" plugin remove yazi
  [ "$status" -eq 0 ]
  [ ! -e "$THEME" ]
  [ -f "$HOME/.config/yazi/yazi.toml" ]
  "$NK" plugin add yazi >/dev/null
  echo mine > "$THEME"
  "$NK" plugin remove yazi >/dev/null
  [ "$(cat "$THEME")" = mine ]
}
