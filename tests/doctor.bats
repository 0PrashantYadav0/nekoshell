#!/usr/bin/env bats
load helpers

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_SKIP_PREFLIGHT=1
  export TERM_PROGRAM=iTerm.app
}
teardown() { teardown_tmp_home; }

@test "doctor fails before install" {
  run "$REPO_ROOT/bin/nekoshell-doctor"
  [ "$status" -ne 0 ]
  assert_contains "$output" "fail"
}

@test "doctor passes with only warns after a fake install" {
  "$REPO_ROOT/install.sh" --yes >/dev/null
  mkdir -p "$HOME/Library/Fonts"; touch "$HOME/Library/Fonts/JetBrainsMonoNerdFont-Regular.ttf"
  run "$REPO_ROOT/bin/nekoshell-doctor"
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "fail"
  assert_matches "$output" 'warn[[:space:]]+spotify'
}

@test "doctor --json emits an array of checks" {
  "$REPO_ROOT/install.sh" --yes >/dev/null
  run bash -c "'$REPO_ROOT/bin/nekoshell-doctor' --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(type(d).__name__, all(k in d[0] for k in (\"check\",\"status\",\"detail\")))'"
  [ "$output" = "list True" ]
}

# Real pokemon art ends on a colour reset with no trailing newline, so the
# timing line reaches the doctor as "<ESC>[mgreet: 108 ms". The parse has to
# survive that or every real machine reports "could not measure".
@test "greet time is measured even when the art leaves an escape on the line" {
  "$REPO_ROOT/install.sh" --yes >/dev/null
  mkdir -p "$HOME/bin"
  cat > "$HOME/bin/fastfetch" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null 2>&1 || true
printf 'art\n\033[m'
EOF
  chmod +x "$HOME/bin/fastfetch"
  PATH="$HOME/bin:$PATH" run "$REPO_ROOT/bin/nekoshell-doctor"
  assert_contains "$output" "greet time"
  assert_not_contains "$output" "could not measure"
  assert_matches "$output" 'greet time[[:space:]]+[0-9]+ ms'
}

# The theme row names the flavour in force. It warns rather than fails, because
# a rig with no recorded flavour still works; it is just wearing whatever colours
# were there before.
@test "the theme row names the flavour, and warns when none is recorded" {
  "$REPO_ROOT/install.sh" --yes >/dev/null
  # The font is the other check that would fail here; satisfy it so the exit
  # status at the end answers for the theme row alone.
  mkdir -p "$HOME/Library/Fonts"; touch "$HOME/Library/Fonts/JetBrainsMonoNerdFont-Regular.ttf"
  run "$REPO_ROOT/bin/nekoshell-doctor"
  assert_matches "$output" 'ok[[:space:]]+theme[[:space:]]+catppuccin mocha'

  "$REPO_ROOT/bin/nekoshell-theme" latte >/dev/null
  run "$REPO_ROOT/bin/nekoshell-doctor"
  assert_matches "$output" 'ok[[:space:]]+theme[[:space:]]+catppuccin latte'

  rm -f "$HOME/.config/nekoshell/theme"
  run "$REPO_ROOT/bin/nekoshell-doctor"
  assert_matches "$output" 'warn[[:space:]]+theme'
  assert_contains "$output" "nekoshell-theme mocha"
  # A missing flavour is a warning, not a failure: the doctor still exits 0.
  [ "$status" -eq 0 ]
}

# The doctor derives the checkout from its own location, so it can tell that the
# recorded root points somewhere else. Reading the root file to find itself made
# this check compare the file to itself and always pass.
@test "doctor reports a stale recorded root" {
  "$REPO_ROOT/install.sh" --yes >/dev/null
  echo '/nowhere/old' > "$HOME/.config/nekoshell/root"
  run "$REPO_ROOT/bin/nekoshell-doctor"
  [ "$status" -ne 0 ]
  assert_matches "$output" 'fail[[:space:]]+root'
}

# neovim and tmux join the rig's tool list, so a machine missing either one
# hears about it from the doctor rather than from a broken alias.
@test "the doctor reports nvim and tmux as tools" {
  "$REPO_ROOT/install.sh" --yes >/dev/null
  run "$REPO_ROOT/bin/nekoshell-doctor"
  assert_contains "$output" "tool: nvim"
  assert_contains "$output" "tool: tmux"
  assert_not_contains "$output" "fail tool: nvim"
  assert_not_contains "$output" "fail tool: tmux"
}
