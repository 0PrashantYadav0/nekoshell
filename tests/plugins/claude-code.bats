#!/usr/bin/env bats
# The claude-code plugin: a rendered theme and status line, two settings
# touched in place and restored, and a wrapper that knows when not to greet.
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes-ai:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  unset ZDOTDIR NEKOSHELL_AI_WELCOME NEKOSHELL_AI_WELCOME_FORCE CLAUDECODE
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/claude-code"
  SETTINGS="$HOME/.claude/settings.json"
  THEME="$HOME/.claude/themes/nekoshell.json"
  STATUS="$HOME/.config/nekoshell/ai/claude-statusline.sh"
  git init -q "$HOME/repo"
  git -C "$HOME/repo" checkout -q -b main
  git -C "$HOME/repo" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q --allow-empty -m "first commit"
}
teardown() { teardown_tmp_home; }

# setting KEY: the JSON value of KEY in settings.json.
setting() { python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(json.dumps(d.get(sys.argv[2])))' "$SETTINGS" "$1"; }

@test "plugin.toml is complete, needs ai, and the README has its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  grep -q '^requires_plugins = \["ai"\]' "$P/plugin.toml"
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
}

@test "add enables ai first, renders the theme and the status line, and sets the two keys" {
  run "$NK" plugin add claude-code
  [ "$status" -eq 0 ]
  assert_contains "$output" "claude-code needs ai; adding it first"
  assert_not_contains "$output" "brew install"
  [ -f "$THEME" ]
  grep -q '"name": "nekoshell Mocha"' "$THEME"
  grep -q '"base": "dark"' "$THEME"
  grep -q '"claude": "#cba6f7"' "$THEME"
  ! grep -q '@@' "$THEME"
  python3 -c 'import json,sys;json.load(open(sys.argv[1]))' "$THEME"
  [ -x "$STATUS" ]
  grep -q '38;2;203;166;247' "$STATUS"
  [ "$(setting theme)" = '"custom:nekoshell"' ]
  [ "$(setting statusLine)" = "{\"type\": \"command\", \"command\": \"$STATUS\"}" ]
}

@test "latte renders a light base" {
  sed -i '' 's/^theme_resolved = .*/theme_resolved = "latte"/' "$HOME/.config/nekoshell/nekoshell.toml"
  "$NK" plugin add claude-code >/dev/null
  grep -q '"base": "light"' "$THEME"
  grep -q '"claude": "#8839ef"' "$THEME"
  grep -q '"name": "nekoshell Latte"' "$THEME"
}

@test "existing settings are kept, the two keys are recorded and restored on remove" {
  mkdir -p "$HOME/.claude"
  echo '{"model": "opus", "theme": "light", "statusLine": {"type": "command", "command": "mine.sh"}}' > "$SETTINGS"
  "$NK" plugin add claude-code >/dev/null
  [ "$(setting model)" = '"opus"' ]
  [ "$(setting theme)" = '"custom:nekoshell"' ]
  run "$NK" theme latte
  [ "$status" -eq 0 ]
  [ "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["theme"])' "$HOME/.config/nekoshell/ai/claude-previous.json")" = "light" ]
  run "$NK" plugin remove claude-code
  [ "$status" -eq 0 ]
  [ "$(setting theme)" = '"light"' ]
  [ "$(setting statusLine)" = '{"type": "command", "command": "mine.sh"}' ]
  [ "$(setting model)" = '"opus"' ]
  [ ! -e "$THEME" ]
  [ ! -e "$STATUS" ]
}

@test "keys that were absent are absent again after remove" {
  "$NK" plugin add claude-code >/dev/null
  "$NK" plugin remove claude-code >/dev/null
  [ "$(setting theme)" = "null" ]
  [ "$(setting statusLine)" = "null" ]
}

@test "the claude function prints the banner on a tty and not for -p or a subcommand" {
  "$NK" plugin add claude-code >/dev/null
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  run script -q /dev/null zsh -o NO_GLOBAL_RCS -ic "cd '$HOME/repo'; claude; exit 0" < /dev/null
  # Through a pty the values are painted, so the sentence is asserted in pieces.
  assert_contains "$output" "Welcome to "
  assert_contains "$output" "Claude Code"
  assert_contains "$output" "You are in "
  assert_matches "$output" 'repo.* on .*main'
  assert_contains "$output" "claude "
  run script -q /dev/null zsh -o NO_GLOBAL_RCS -ic "cd '$HOME/repo'; claude -p hi; claude mcp list; exit 0" < /dev/null
  assert_not_contains "$output" "Welcome"
  assert_contains "$output" "claude -p hi"
  assert_contains "$output" "claude mcp list"
  run zsh -o NO_GLOBAL_RCS -ic "cd '$HOME/repo'; claude; exit 0"
  assert_not_contains "$output" "Welcome"
}

@test "without claude on PATH no function is defined" {
  "$NK" plugin add claude-code >/dev/null
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  run env PATH="/usr/bin:/bin" zsh -o NO_GLOBAL_RCS -ic '(( $+functions[claude] )) && echo DEFINED; echo DONE; exit 0'
  assert_contains "$output" "DONE"
  assert_not_contains "$output" "DEFINED"
}

@test "the status line prints model, directory, branch and context use from the JSON on stdin" {
  "$NK" plugin add claude-code >/dev/null
  run bash -c "printf '%s' '{\"model\":{\"display_name\":\"Opus\"},\"workspace\":{\"current_dir\":\"$HOME/repo\"},\"context_window\":{\"used_percentage\":42.5}}' | '$STATUS'"
  [ "$status" -eq 0 ]
  assert_contains "$output" "Opus"
  assert_contains "$output" "repo"
  assert_contains "$output" "main"
  assert_contains "$output" "42%"
  run bash -c "printf '%s' '{}' | '$STATUS'"
  [ "$status" -eq 0 ]
}

@test "install warns when claude is missing" {
  run env PATH="/usr/bin:/bin" "$NK" plugin add claude-code
  [ "$status" -eq 0 ]
  assert_contains "$output" "claude is not on PATH; install it with: brew install --cask claude-code"
}

@test "doctor reports the binary, the theme and the status line" {
  "$NK" plugin add claude-code >/dev/null
  run "$NK" doctor --plugin claude-code
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +tool: claude'
  assert_matches "$output" 'ok +claude theme +mocha \(custom:nekoshell\)'
  assert_matches "$output" 'ok +claude status line'
  echo '{"theme": "dark"}' > "$SETTINGS"
  run "$NK" doctor --plugin claude-code
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +claude theme'
  assert_matches "$output" 'fail +claude status line'
}
