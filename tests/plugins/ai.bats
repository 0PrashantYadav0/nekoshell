#!/usr/bin/env bats
# The ai plugin: the banner, its templates, nekoshell ai, and the JSON helpers
# the tool plugins share.
load ../helpers
setup() {
  setup_tmp_home
  # Not the usual fakes directory: its git fake would shadow the real git the
  # banner reads the repository with. fakes-ai holds only what these plugins
  # touch (brew, claude, opencode, defaults, sw_vers).
  export PATH="$REPO_ROOT/tests/fakes-ai:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  unset ZDOTDIR NEKOSHELL_AI_WELCOME NEKOSHELL_AI_WELCOME_FORCE
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/ai"
  W="$P/bin/nekoshell-ai-welcome"
  # A repository with one commit, on main.
  git init -q "$HOME/repo"
  git -C "$HOME/repo" checkout -q -b main
  git -C "$HOME/repo" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q --allow-empty -m "first commit"
}
teardown() { teardown_tmp_home; }

@test "plugin.toml is complete and the README has its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
}

@test "add copies the two templates once and renders the colours" {
  run "$NK" plugin add ai
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "brew install"
  [ -f "$HOME/.config/nekoshell/ai/welcome.txt" ]
  [ -f "$HOME/.config/nekoshell/ai/welcome-norepo.txt" ]
  grep -q "Mocha" "$HOME/.config/nekoshell/ai/colors.sh"
  grep -q "38;2;203;166;247" "$HOME/.config/nekoshell/ai/colors.sh"
  echo 'mine' > "$HOME/.config/nekoshell/ai/welcome.txt"
  "$NK" plugin add ai >/dev/null
  [ "$(cat "$HOME/.config/nekoshell/ai/welcome.txt")" = mine ]
}

@test "the banner names the tool, the project, the branch and the last commit" {
  "$NK" plugin add ai >/dev/null
  cd "$HOME/repo"
  NEKOSHELL_AI_WELCOME_FORCE=1 run "$W" claude-code
  [ "$status" -eq 0 ]
  assert_contains "$output" "Welcome to Claude Code. You are in repo on main."
  assert_matches "$output" 'Last commit [0-9a-f]{7} "first commit" .* ago\.'
  assert_not_contains "$output" $'\033'
}

@test "outside a repository the banner says so" {
  "$NK" plugin add ai >/dev/null
  cd "$HOME"
  NEKOSHELL_AI_WELCOME_FORCE=1 run "$W" opencode
  [ "$output" = "Welcome to OpenCode. You are in ~, not a git repository." ]
}

@test "a repository with no commits yet still gets a banner" {
  "$NK" plugin add ai >/dev/null
  git init -q "$HOME/empty"
  cd "$HOME/empty"
  NEKOSHELL_AI_WELCOME_FORCE=1 run "$W" claude-code
  [ "$status" -eq 0 ]
  assert_contains "$output" "You are in empty on"
  assert_contains "$output" 'Last commit none "no commits yet" ever.'
}

@test "a per-tool template wins, and the shared one is used otherwise" {
  "$NK" plugin add ai >/dev/null
  echo 'Hi from @@TOOL@@ in @@PROJECT@@' > "$HOME/.config/nekoshell/ai/welcome.claude-code.txt"
  cd "$HOME/repo"
  NEKOSHELL_AI_WELCOME_FORCE=1 run "$W" claude-code
  [ "$output" = "Hi from Claude Code in repo" ]
  NEKOSHELL_AI_WELCOME_FORCE=1 run "$W" opencode
  assert_contains "$output" "Welcome to OpenCode. You are in repo on main."
}

@test "without templates the built-in text is used" {
  cd "$HOME/repo"
  NEKOSHELL_AI_WELCOME_FORCE=1 run "$W" codex
  assert_contains "$output" "Welcome to Codex. You are in repo on main."
}

@test "silent when stdout is not a tty, when switched off, and with no tool" {
  "$NK" plugin add ai >/dev/null
  cd "$HOME/repo"
  run "$W" claude-code
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  NEKOSHELL_AI_WELCOME=0 NEKOSHELL_AI_WELCOME_FORCE=1 run "$W" claude-code
  [ -z "$output" ]
  NEKOSHELL_AI_WELCOME_FORCE=1 run "$W"
  [ -z "$output" ]
}

@test "on a tty the values are painted in the accent colour" {
  "$NK" plugin add ai >/dev/null
  cd "$HOME/repo"
  run script -q /dev/null "$W" claude-code < /dev/null
  assert_contains "$output" $'\033[38;2;203;166;247mClaude Code'
}

@test "nekoshell ai welcome previews, status lists the tools, edit wants a template" {
  "$NK" plugin add ai >/dev/null
  cd "$HOME/repo"
  run "$NK" ai welcome opencode
  [ "$status" -eq 0 ]
  assert_contains "$output" "Welcome to OpenCode. You are in repo on main."
  run "$NK" ai welcome
  assert_contains "$output" "Welcome to Claude Code."
  run "$NK" ai status
  [ "$status" -eq 0 ]
  assert_matches "$output" 'claude-code +not enabled +.*claude +shared template'
  assert_matches "$output" 'opencode +not enabled'
  rm "$HOME/.config/nekoshell/ai/welcome.txt"
  run "$NK" ai edit
  [ "$status" -eq 1 ]
  run "$NK" ai
  [ "$status" -eq 2 ]
}

@test "ai_json_set records the previous value once and restore puts it back" {
  source "$REPO_ROOT/core/lib/log.sh"
  source "$P/lib.sh"
  echo '{"model": "opus", "theme": "dark"}' > "$HOME/s.json"
  ai_json_set "$HOME/s.json" theme '"custom:nekoshell"' "$HOME/prev.json"
  ai_json_set "$HOME/s.json" theme '"custom:nekoshell"' "$HOME/prev.json"
  [ "$(ai_json_get "$HOME/s.json" theme)" = '"custom:nekoshell"' ]
  [ "$(ai_json_get "$HOME/prev.json" theme)" = '"dark"' ]
  [ "$(ai_json_get "$HOME/s.json" model)" = '"opus"' ]
  ai_json_restore "$HOME/s.json" theme "$HOME/prev.json"
  [ "$(ai_json_get "$HOME/s.json" theme)" = '"dark"' ]
  [ -z "$(ai_json_get "$HOME/prev.json" theme)" ]
  ai_json_set "$HOME/s.json" statusLine '{"type":"command","command":"x"}' "$HOME/prev.json"
  [ "$(ai_json_get "$HOME/s.json" statusLine)" = '{"type": "command", "command": "x"}' ]
  ai_json_restore "$HOME/s.json" statusLine "$HOME/prev.json"
  [ -z "$(ai_json_get "$HOME/s.json" statusLine)" ]
  [ "$(ai_json_get "$HOME/s.json" model)" = '"opus"' ]
}

@test "ai_json_set creates a missing file and a dry run writes nothing" {
  source "$REPO_ROOT/core/lib/log.sh"
  source "$P/lib.sh"
  ai_json_set "$HOME/new/t.json" theme '"nekoshell"' "$HOME/new/prev.json"
  [ "$(ai_json_get "$HOME/new/t.json" theme)" = '"nekoshell"' ]
  NEKOSHELL_DRY_RUN=1 ai_json_set "$HOME/dry.json" theme '"x"' "$HOME/dryprev.json"
  [ ! -e "$HOME/dry.json" ]
}

@test "doctor reports the templates and the colours" {
  "$NK" plugin add ai >/dev/null
  run "$NK" doctor --plugin ai
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +ai templates'
  assert_matches "$output" 'ok +ai colours +mocha'
  rm "$HOME/.config/nekoshell/ai/colors.sh"
  run "$NK" doctor --plugin ai
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +ai colours'
}
