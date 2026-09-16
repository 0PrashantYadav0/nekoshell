#!/usr/bin/env bats
# The vscode plugin: two keys in VS Code's settings.json set from the
# terminal id, the rest of a commented file left byte for byte, both keys
# restored on remove, and a doctor that knows which apps the debug console
# can open.
load ../helpers
setup() {
  setup_tmp_home
  # A fake `code` under HOME stands for an installed VS Code; a test without
  # VS Code deletes it. The app bundle check points under HOME too, so a Mac
  # with the real VS Code in /Applications tests the same as one without.
  mkdir -p "$HOME/bin"
  printf '#!/bin/sh\nexit 0\n' >"$HOME/bin/code"
  chmod +x "$HOME/bin/code"
  export PATH="$HOME/bin:$REPO_ROOT/tests/fakes:/usr/bin:/bin"
  export NEKOSHELL_VSCODE_APP="$HOME/Applications/Visual Studio Code.app"
  export NEKOSHELL_VSCODE_SETTINGS="$HOME/Code/User/settings.json"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "kitty"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" >"$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/vscode"
  SETTINGS="$NEKOSHELL_VSCODE_SETTINGS"
  PREV="$HOME/.config/nekoshell/vscode/previous.json"
}
teardown() { teardown_tmp_home; }

# setting KEY: the JSON value of KEY in settings.json, "null" when absent.
# Strict JSON on purpose: the files these tests write without comments must
# still be strict JSON after the plugin touched them.
setting() { python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(json.dumps(d.get(sys.argv[2])))' "$SETTINGS" "$1"; }
# previous KEY: the recorded value of KEY, "null" when recorded as absent.
previous() { python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(json.dumps(d.get(sys.argv[2])))' "$PREV" "$1"; }
# use_terminal ID: the terminal id nekoshell.toml names.
use_terminal() { sed -i '' "s/^terminal = .*/terminal = \"$1\"/" "$HOME/.config/nekoshell/nekoshell.toml"; }
no_code() { rm -f "$HOME/bin/code"; }

@test "plugin.toml has the nine keys and the README its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  grep -q '^casks = \[\]' "$P/plugin.toml"
  grep -q '^terminals = \["any"\]' "$P/plugin.toml"
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
}

@test "add sets both keys for the configured terminal id and records the previous values" {
  run "$NK" plugin add vscode
  [ "$status" -eq 0 ]
  assert_contains "$output" "terminal.external.osxExec = kitty.app (kitty)"
  assert_contains "$output" "terminal.explorerKind = both"
  assert_not_contains "$output" "brew install"
  [ "$(setting terminal.external.osxExec)" = '"kitty.app"' ]
  [ "$(setting terminal.explorerKind)" = '"both"' ]
  [ "$(previous terminal.external.osxExec)" = "null" ]
  [ "$(previous terminal.explorerKind)" = "null" ]
}

@test "every terminal id maps to its app" {
  local id app
  for pair in ghostty:Ghostty.app iterm2:iTerm.app warp:Warp.app terminal-app:Terminal.app; do
    id="${pair%%:*}"
    app="${pair#*:}"
    use_terminal "$id"
    "$NK" plugin add vscode >/dev/null
    [ "$(setting terminal.external.osxExec)" = "\"$app\"" ]
    "$NK" plugin remove vscode >/dev/null
  done
}

@test "add keeps comments, trailing commas and the other keys byte for byte" {
  mkdir -p "$(dirname "$SETTINGS")"
  cat >"$SETTINGS" <<'JSONC'
{
  // the editor
  "editor.fontSize": 14,
  /* a block
     comment */
  "workbench.colorCustomizations": {
    "terminal.external.osxExec": "not.this.one",
  },
  "terminal.explorerKind": "integrated", // keep me
  "files.trimTrailingWhitespace": true,
}
JSONC
  cp "$SETTINGS" "$HOME/before.json"
  run "$NK" plugin add vscode
  [ "$status" -eq 0 ]
  grep -qF '  // the editor' "$SETTINGS"
  grep -qF '  /* a block' "$SETTINGS"
  grep -qF '     comment */' "$SETTINGS"
  grep -qF '  "terminal.external.osxExec": "kitty.app",' "$SETTINGS"
  grep -qF '  "terminal.explorerKind": "both", // keep me' "$SETTINGS"
  grep -qF '    "terminal.external.osxExec": "not.this.one",' "$SETTINGS"
  # Every line that is not one of our two keys is unchanged and in order.
  diff <(grep -vE '^  "terminal\.(external\.osxExec|explorerKind)"' "$HOME/before.json") \
    <(grep -vE '^  "terminal\.(external\.osxExec|explorerKind)"' "$SETTINGS")
  [ "$(previous terminal.external.osxExec)" = "null" ]
  [ "$(previous terminal.explorerKind)" = '"integrated"' ]
  "$NK" plugin remove vscode >/dev/null
  diff "$HOME/before.json" "$SETTINGS"
}

@test "add replaces only the line of a key that already exists" {
  mkdir -p "$(dirname "$SETTINGS")"
  printf '{\n  "editor.fontSize": 14,\n  "terminal.external.osxExec": "Terminal.app",\n  "terminal.explorerKind": "external"\n}\n' >"$SETTINGS"
  "$NK" plugin add vscode >/dev/null
  [ "$(wc -l <"$SETTINGS")" -eq 5 ]
  [ "$(sed -n 2p "$SETTINGS")" = '  "editor.fontSize": 14,' ]
  [ "$(sed -n 3p "$SETTINGS")" = '  "terminal.external.osxExec": "kitty.app",' ]
  [ "$(sed -n 4p "$SETTINGS")" = '  "terminal.explorerKind": "both"' ]
  [ "$(previous terminal.external.osxExec)" = '"Terminal.app"' ]
  [ "$(previous terminal.explorerKind)" = '"external"' ]
}

@test "add with a missing settings file creates it" {
  [ ! -e "$SETTINGS" ]
  "$NK" plugin add vscode >/dev/null
  [ -f "$SETTINGS" ]
  [ "$(setting terminal.external.osxExec)" = '"kitty.app"' ]
  [ "$(setting terminal.explorerKind)" = '"both"' ]
  [ "$(head -c 1 "$SETTINGS")" = "{" ]
  [ "$(tail -c 2 "$SETTINGS")" = "}" ]
}

@test "add with a terminal id not in the table sets only explorerKind and warns" {
  use_terminal fake
  run "$NK" plugin add vscode
  [ "$status" -eq 0 ]
  assert_contains "$output" "no VS Code app name is known for terminal 'fake'"
  assert_contains "$output" "nekoshell vscode terminal <id|App.app>"
  [ "$(setting terminal.external.osxExec)" = "null" ]
  [ "$(setting terminal.explorerKind)" = '"both"' ]
  ! grep -q osxExec "$PREV"
}

@test "add without VS Code and without the settings directory writes nothing and warns" {
  no_code
  run "$NK" plugin add vscode
  [ "$status" -eq 0 ]
  assert_contains "$output" "VS Code is not installed (brew install --cask visual-studio-code); nothing written"
  [ ! -e "$SETTINGS" ]
  [ ! -e "$PREV" ]
}

@test "add without VS Code but with the settings directory writes the keys and warns" {
  no_code
  mkdir -p "$(dirname "$SETTINGS")"
  run "$NK" plugin add vscode
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install --cask visual-studio-code"
  [ "$(setting terminal.explorerKind)" = '"both"' ]
}

@test "a dry run writes nothing" {
  run env NEKOSHELL_DRY_RUN=1 "$NK" plugin add vscode
  [ "$status" -eq 0 ]
  assert_contains "$output" "would set terminal.external.osxExec"
  assert_contains "$output" "would set terminal.explorerKind"
  [ ! -e "$SETTINGS" ]
  [ ! -e "$PREV" ]
  grep -q '^plugins = \[\]' "$HOME/.config/nekoshell/nekoshell.toml"
}

@test "remove restores a previous value and removes a key that was absent" {
  mkdir -p "$(dirname "$SETTINGS")"
  printf '{\n  "editor.fontSize": 14,\n  "terminal.explorerKind": "integrated"\n}\n' >"$SETTINGS"
  "$NK" plugin add vscode >/dev/null
  [ "$(setting terminal.external.osxExec)" = '"kitty.app"' ]
  run "$NK" plugin remove vscode
  [ "$status" -eq 0 ]
  [ "$(setting terminal.external.osxExec)" = "null" ]
  [ "$(setting terminal.explorerKind)" = '"integrated"' ]
  [ "$(setting editor.fontSize)" = "14" ]
  ! grep -q osxExec "$SETTINGS"
  [ "$(cat "$PREV")" = "{}" ]
}

@test "a second add does not overwrite the recorded previous value" {
  mkdir -p "$(dirname "$SETTINGS")"
  printf '{\n  "terminal.explorerKind": "integrated"\n}\n' >"$SETTINGS"
  "$NK" plugin add vscode >/dev/null
  "$NK" plugin remove vscode >/dev/null
  "$NK" plugin add vscode >/dev/null
  "$NK" plugin add vscode >/dev/null
  [ "$(previous terminal.explorerKind)" = '"integrated"' ]
  "$NK" plugin remove vscode >/dev/null
  [ "$(setting terminal.explorerKind)" = '"integrated"' ]
}

@test "doctor is ok after add, except the debug console for kitty" {
  "$NK" plugin add vscode >/dev/null
  run "$NK" doctor --plugin vscode
  [ "$status" -eq 0 ]
  assert_matches "$output" "ok +tool: code +$HOME/bin/code"
  assert_matches "$output" 'ok +external terminal +kitty\.app \(kitty\)'
  assert_matches "$output" 'warn +debug console +"console": "externalTerminal" in launch.json is not supported by VS Code for kitty\.app'
  assert_not_matches "$output" '^fail '
}

@test "doctor warns about the debug console for Warp and not for Ghostty" {
  use_terminal warp
  "$NK" plugin add vscode >/dev/null
  run "$NK" doctor --plugin vscode
  assert_matches "$output" 'ok +external terminal +Warp\.app \(warp\)'
  assert_matches "$output" 'warn +debug console +.*not supported by VS Code for Warp\.app'
  "$NK" plugin remove vscode >/dev/null
  use_terminal ghostty
  "$NK" plugin add vscode >/dev/null
  run "$NK" doctor --plugin vscode
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +external terminal +Ghostty\.app \(ghostty\)'
  assert_matches "$output" 'ok +debug console +Ghostty\.app'
}

@test "doctor rows are warn, not fail, without VS Code" {
  no_code
  run "$NK" doctor --plugin vscode
  [ "$status" -eq 0 ]
  assert_matches "$output" 'warn +tool: code +not installed \(brew install --cask visual-studio-code\)'
  assert_matches "$output" 'warn +external terminal +not set and VS Code not installed'
  assert_not_matches "$output" '^fail '
}

@test "doctor fails when the key is unset while VS Code is installed, and warns for an unknown id" {
  "$NK" plugin add vscode >/dev/null
  printf '{}\n' >"$SETTINGS"
  run "$NK" doctor --plugin vscode
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +external terminal +not set while VS Code is installed \(run: nekoshell vscode terminal kitty\)'
  assert_matches "$output" "ok +debug console +Terminal\\.app \\(VS Code's default\\)"
  use_terminal fake
  run "$NK" doctor --plugin vscode
  [ "$status" -eq 0 ]
  assert_matches "$output" "warn +external terminal +not set: no VS Code app name is known for 'fake'"
}

@test "vscode terminal prints the app and its id after add, and not set on a fresh file" {
  "$NK" plugin add vscode >/dev/null
  run "$NK" vscode terminal
  [ "$status" -eq 0 ]
  [ "$output" = "kitty.app (kitty)" ]
  printf '{}\n' >"$SETTINGS"
  run "$NK" vscode terminal
  [ "$status" -eq 0 ]
  [ "$output" = "not set (VS Code opens Terminal.app)" ]
  rm "$SETTINGS"
  run "$NK" vscode terminal
  [ "$status" -eq 0 ]
  [ "$output" = "not set (VS Code opens Terminal.app)" ]
}

@test "vscode terminal ID sets the key to the app and prints ok" {
  "$NK" plugin add vscode >/dev/null
  run "$NK" vscode terminal ghostty
  [ "$status" -eq 0 ]
  assert_matches "$output" '^ok +VS Code opens Ghostty\.app$'
  [ "$(setting terminal.external.osxExec)" = '"Ghostty.app"' ]
  run "$NK" vscode terminal
  [ "$output" = "Ghostty.app (ghostty)" ]
  # The previous value is the one add recorded, not what the command replaced.
  [ "$(previous terminal.external.osxExec)" = "null" ]
}

@test "vscode terminal App.app passes a name outside the table through" {
  "$NK" plugin add vscode >/dev/null
  run "$NK" vscode terminal Alacritty.app
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +VS Code opens Alacritty\.app'
  [ "$(setting terminal.external.osxExec)" = '"Alacritty.app"' ]
  run "$NK" vscode terminal
  [ "$output" = "Alacritty.app" ]
}

@test "vscode terminal foo fails, exits 1 and writes nothing" {
  "$NK" plugin add vscode >/dev/null
  cp "$SETTINGS" "$HOME/before.json"
  cp "$PREV" "$HOME/prev-before.json"
  run "$NK" vscode terminal foo
  [ "$status" -eq 1 ]
  assert_matches "$output" '^fail +foo is not a terminal nekoshell knows \(kitty, ghostty, iterm2, warp, terminal-app\) and does not end in \.app$'
  diff "$HOME/before.json" "$SETTINGS"
  diff "$HOME/prev-before.json" "$PREV"
}

@test "vscode terminal warns about the debug console for kitty and not for ghostty" {
  use_terminal ghostty
  "$NK" plugin add vscode >/dev/null
  run "$NK" vscode terminal kitty
  [ "$status" -eq 0 ]
  assert_matches "$output" 'warn +"console": "externalTerminal" in launch.json is not supported by VS Code for kitty\.app'
  run "$NK" vscode terminal ghostty
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "not supported"
  run "$NK" vscode terminal Warp.app
  assert_matches "$output" 'warn +.*not supported by VS Code for Warp\.app'
}

@test "vscode terminal records the previous value once, so remove restores the original" {
  mkdir -p "$(dirname "$SETTINGS")"
  printf '{\n  "terminal.external.osxExec": "Terminal.app"\n}\n' >"$SETTINGS"
  "$NK" plugin add vscode >/dev/null
  "$NK" vscode terminal warp >/dev/null
  "$NK" vscode terminal iterm2 >/dev/null
  [ "$(previous terminal.external.osxExec)" = '"Terminal.app"' ]
  "$NK" plugin remove vscode >/dev/null
  [ "$(setting terminal.external.osxExec)" = '"Terminal.app"' ]
}

@test "vscode terminal in a dry run says what it would set and writes nothing" {
  "$NK" plugin add vscode >/dev/null
  cp "$SETTINGS" "$HOME/before.json"
  run env NEKOSHELL_DRY_RUN=1 "$NK" vscode terminal ghostty
  [ "$status" -eq 0 ]
  assert_contains "$output" 'would set terminal.external.osxExec to "Ghostty.app"'
  assert_not_contains "$output" "VS Code opens"
  diff "$HOME/before.json" "$SETTINGS"
}

@test "vscode -h prints usage and exits 0, an unknown subcommand exits 2" {
  "$NK" plugin add vscode >/dev/null
  run "$NK" vscode -h
  [ "$status" -eq 0 ]
  assert_contains "$output" "usage: nekoshell vscode terminal"
  run "$NK" vscode help
  [ "$status" -eq 0 ]
  run "$NK" vscode
  [ "$status" -eq 2 ]
  assert_contains "$output" "usage: nekoshell vscode terminal"
  run "$NK" vscode bogus
  [ "$status" -eq 2 ]
  run "$NK" vscode terminal kitty extra
  [ "$status" -eq 2 ]
  [ "$(setting terminal.external.osxExec)" = '"kitty.app"' ]
}

@test "nekoshell vscode exists only while the plugin is enabled" {
  run "$NK" vscode terminal
  [ "$status" -eq 2 ]
  assert_contains "$output" "provided by the vscode plugin, which is not enabled"
}

@test "help lists vscode under Plugin commands, enabled or not" {
  run "$NK" help
  [ "$status" -eq 0 ]
  assert_contains "$output" "Plugin commands:"
  assert_matches "$output" 'vscode +\(plugin vscode, not enabled\)'
  "$NK" plugin add vscode >/dev/null
  run "$NK" help
  assert_matches "$output" 'vscode +\(plugin vscode, enabled\)'
}

@test "doctor names the id that matches the app after vscode terminal, or the app alone" {
  "$NK" plugin add vscode >/dev/null
  "$NK" vscode terminal ghostty >/dev/null
  run "$NK" doctor --plugin vscode
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +external terminal +Ghostty\.app \(ghostty\)'
  assert_not_contains "$output" "(kitty)"
  "$NK" vscode terminal Alacritty.app >/dev/null
  run "$NK" doctor --plugin vscode
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +external terminal +Alacritty\.app'
  assert_not_contains "$output" "Alacritty.app ("
  assert_matches "$output" 'warn +debug console +.*not supported by VS Code for Alacritty\.app'
}
