#!/usr/bin/env bats
# The opencode plugin: a rendered theme, one tui.json key touched and
# restored, and the wrapper.
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes-ai:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  unset ZDOTDIR NEKOSHELL_AI_WELCOME NEKOSHELL_AI_WELCOME_FORCE
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/opencode"
  TUI="$HOME/.config/opencode/tui.json"
  THEME="$HOME/.config/opencode/themes/nekoshell.json"
  git init -q "$HOME/repo"
  git -C "$HOME/repo" checkout -q -b main
  git -C "$HOME/repo" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q --allow-empty -m "first commit"
}
teardown() { teardown_tmp_home; }

tui() { python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(json.dumps(d.get(sys.argv[2])))' "$TUI" "$1"; }

@test "plugin.toml is complete, needs ai, and the README has its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  grep -q '^requires_plugins = \["ai"\]' "$P/plugin.toml"
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
}

@test "the template names every one of OpenCode's fifty theme keys and no literal colour" {
  run python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
keys=set(d["theme"]); defs=set(d["defs"])
print(len(keys)); print(all(v in defs for v in d["theme"].values()))' "$P/files/theme.json.tmpl"
  [ "${lines[0]}" = "50" ]
  [ "${lines[1]}" = "True" ]
  run grep -c '#[0-9a-fA-F]\{6\}' "$P/files/theme.json.tmpl"
  [ "$output" = "0" ]
}

@test "add installs opencode, renders the theme and points tui.json at it" {
  run "$NK" plugin add opencode
  [ "$status" -eq 0 ]
  assert_contains "$output" "opencode needs ai; adding it first"
  assert_contains "$output" "brew install opencode"
  [ -f "$THEME" ]
  grep -q '"base": "#1e1e2e"' "$THEME"
  python3 -c 'import json,sys;json.load(open(sys.argv[1]))' "$THEME"
  [ "$(tui theme)" = '"nekoshell"' ]
}

@test "latte re-renders, and existing tui.json keys survive" {
  mkdir -p "$HOME/.config/opencode"
  echo '{"theme": "gruvbox", "scroll_speed": 3}' > "$TUI"
  "$NK" plugin add opencode >/dev/null
  [ "$(tui scroll_speed)" = "3" ]
  run "$NK" theme latte
  [ "$status" -eq 0 ]
  grep -q '"base": "#eff1f5"' "$THEME"
  [ "$(tui theme)" = '"nekoshell"' ]
  run "$NK" plugin remove opencode
  [ "$status" -eq 0 ]
  [ "$(tui theme)" = '"gruvbox"' ]
  [ "$(tui scroll_speed)" = "3" ]
  [ ! -e "$THEME" ]
}

@test "the opencode function prints the banner on a tty and not for run" {
  "$NK" plugin add opencode >/dev/null
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  run script -q /dev/null zsh -o NO_GLOBAL_RCS -ic "cd '$HOME/repo'; opencode; exit 0" < /dev/null
  assert_contains "$output" "Welcome to "
  assert_contains "$output" "OpenCode"
  assert_contains "$output" "opencode "
  run script -q /dev/null zsh -o NO_GLOBAL_RCS -ic "cd '$HOME/repo'; opencode run hi; exit 0" < /dev/null
  assert_not_contains "$output" "Welcome"
  assert_contains "$output" "opencode run hi"
}

@test "doctor reports the binary, the theme and the setting" {
  "$NK" plugin add opencode >/dev/null
  run "$NK" doctor --plugin opencode
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +tool: opencode'
  assert_matches "$output" 'ok +opencode theme +mocha \(nekoshell\)'
  echo '{"theme": "gruvbox"}' > "$TUI"
  run "$NK" doctor --plugin opencode
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +opencode theme'
}
