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
  [[ "$output" == *"fail"* ]]
}

@test "doctor passes with only warns after a fake install" {
  "$REPO_ROOT/install.sh" --yes >/dev/null
  mkdir -p "$HOME/Library/Fonts"; touch "$HOME/Library/Fonts/JetBrainsMonoNerdFont-Regular.ttf"
  run "$REPO_ROOT/bin/nekoshell-doctor"
  [ "$status" -eq 0 ]
  [[ "$output" != *"fail"* ]]
  [[ "$output" == *"warn"*"spotify"* ]]
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
  [[ "$output" == *"greet time"* ]]
  [[ "$output" != *"could not measure"* ]]
  [[ "$output" =~ greet\ time[[:space:]]+[0-9]+\ ms ]]
}
