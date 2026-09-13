#!/usr/bin/env bats
load ../helpers

# AeroSpace tiles macOS windows (i3-style); tmux tiles panes inside one
# terminal window. The two sit beside each other. AeroSpace needs the
# Accessibility permission and its own Homebrew tap, which is exactly why it
# is a plugin you add rather than something every install does.

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  export FAKE_BREW_CASKS=""
  export FAKE_BREW_TAPS=""
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/aerospace"
  CONF="$P/files/copy/.config/aerospace/aerospace.toml"
}
teardown() { teardown_tmp_home; }

@test "plugin.toml is complete and the README has its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  grep -q '^copy_guard *=' "$P/plugin.toml"
  grep -q '^casks *= *\["aerospace"\]$' "$P/plugin.toml"
  grep -q '^taps *= *\["nikitabobko/tap"\]$' "$P/plugin.toml"
  grep -q '^tags *= *\["system"\]$' "$P/plugin.toml"
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
  grep -qF "Accessibility" "$P/README.md"
}

@test "add taps nikitabobko, installs the cask and copies the config unlinked" {
  run "$NK" plugin add aerospace
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew tap nikitabobko/tap"
  assert_contains "$output" "brew install --cask aerospace"
  [ -f "$HOME/.config/aerospace/aerospace.toml" ]
  [ ! -L "$HOME/.config/aerospace/aerospace.toml" ]
  grep -q 'nekoshell AeroSpace config' "$HOME/.config/aerospace/aerospace.toml"
}

@test "a second add keeps your edit" {
  "$NK" plugin add aerospace >/dev/null
  echo '# mine' >> "$HOME/.config/aerospace/aerospace.toml"
  "$NK" plugin add aerospace >/dev/null
  grep -q '# mine' "$HOME/.config/aerospace/aerospace.toml"
}

@test "an existing AeroSpace config stops the copy, loudly" {
  mkdir -p "$HOME/.config/aerospace"
  echo '# my own aerospace config' > "$HOME/.config/aerospace/aerospace.toml"
  run "$NK" plugin add aerospace
  [ "$status" -eq 0 ]
  assert_contains "$output" "aerospace: .config/aerospace/aerospace.toml exists; left your config alone"
  [ "$(cat "$HOME/.config/aerospace/aerospace.toml")" = "# my own aerospace config" ]
}

@test "the shipped config parses as toml, floats the panel, and never binds alt-m" {
  run python3 -c "
import tomllib
with open('$CONF', 'rb') as f:
    data = tomllib.load(f)
binding = data['mode']['main']['binding']
assert 'alt-m' not in binding, 'alt-m is reserved for the Spotify panel'
rules = data['on-window-detected']
assert any(
    r.get('if', {}).get('app-id') == 'com.googlecode.iterm2'
    and 'nekoshell panel' in r.get('if', {}).get('window-title-regex-substring', '')
    and r.get('run') == 'layout floating'
    for r in rules
), 'missing the panel float rule'
print('ok')
"
  [ "$status" -eq 0 ]
  assert_contains "$output" "ok"
}

@test "doctor reports aerospace ok when the tool answers" {
  "$NK" plugin add aerospace >/dev/null
  run "$NK" doctor --plugin aerospace
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +aerospace'
}

# A cask that needs a permission dialog is not something an install can finish
# on its own, so a missing AeroSpace is a note, never a failure that turns the
# whole doctor red.
@test "doctor warns and never fails when AeroSpace is missing" {
  "$NK" plugin add aerospace >/dev/null
  run env PATH="/usr/bin:/bin" "$NK" doctor --plugin aerospace
  [ "$status" -eq 0 ]
  assert_matches "$output" 'warn +aerospace'
  assert_not_contains "$output" "fail aerospace"
  assert_contains "$output" "nekoshell plugin add aerospace"
}

@test "remove drops the plugin and leaves the copied config alone" {
  "$NK" plugin add aerospace >/dev/null
  run "$NK" plugin remove aerospace
  [ "$status" -eq 0 ]
  [ -f "$HOME/.config/aerospace/aerospace.toml" ]
  [ "$(grep '^plugins' "$HOME/.config/nekoshell/nekoshell.toml")" = 'plugins = []' ]
}
