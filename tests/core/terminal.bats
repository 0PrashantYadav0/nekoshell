#!/usr/bin/env bats
load ../helpers
setup() {
  setup_tmp_home
  export NEKOSHELL_ROOT="$REPO_ROOT"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  for l in paths log config terminal; do source "$REPO_ROOT/core/lib/$l.sh"; done
  mkdir -p "$NEKOSHELL_CONFIG" "$NEKOSHELL_CACHE"
  unset TERM_PROGRAM KITTY_WINDOW_ID GHOSTTY_RESOURCES_DIR WEZTERM_EXECUTABLE
  # Pin TERM so terminal_detect_env's xterm-kitty check does not pick up
  # whatever terminal this test happens to be run from (e.g. TERM=xterm-kitty).
  export TERM=xterm-256color
}
teardown() { teardown_tmp_home; }

# Not bats `run`: log.sh (sourced above) defines its own run(), which shadows
# bats' run() for the rest of each test process and would leave $output
# empty. Plain command substitution captures stdout/stderr and exit status
# instead.

@test "terminal_all lists adapters" { [ "$(terminal_all | tr '\n' ' ')" = "bare fake " ]; }
@test "terminal_detect_env maps env vars to ids" {
  status=0; output="$(TERM_PROGRAM=iTerm.app terminal_detect_env)" || status=$?
  [ "$output" = "iterm2" ]
  status=0; output="$(KITTY_WINDOW_ID=1 terminal_detect_env)" || status=$?
  [ "$output" = "kitty" ]
  status=0; output="$(TERM=xterm-kitty terminal_detect_env)" || status=$?
  [ "$output" = "kitty" ]
  status=0; output="$(GHOSTTY_RESOURCES_DIR=/x terminal_detect_env)" || status=$?
  [ "$output" = "ghostty" ]
  status=0; output="$(TERM_PROGRAM=ghostty terminal_detect_env)" || status=$?
  [ "$output" = "ghostty" ]
  status=0; output="$(TERM_PROGRAM=Apple_Terminal terminal_detect_env)" || status=$?
  [ "$output" = "terminal-app" ]
  status=0; output="$(TERM_PROGRAM=WarpTerminal terminal_detect_env)" || status=$?
  [ "$output" = "warp" ]
  status=0; output="$(WEZTERM_EXECUTABLE=/x terminal_detect_env)" || status=$?
  [ "$output" = "wezterm" ]
  status=0; output="$(TERM_PROGRAM=WezTerm terminal_detect_env)" || status=$?
  [ "$output" = "wezterm" ]
  status=0; output="$(TERM=xterm terminal_detect_env)" || status=$?
  [ -z "$output" ]; [ "$status" -eq 1 ]
}
@test "terminal_load defines the adapter functions and defaults" {
  terminal_load fake
  [ "$(terminal_name)" = "fake" ]
  [ "$(terminal_capabilities)" = "truecolor images background panel" ]
  terminal_load bare
  status=0; output="$(terminal_background /x.png 2>&1)" || status=$?
  [ "$status" -eq 1 ]; assert_contains "$output" "not supported by bare"
  [ "$(terminal_font_name)" = "JetBrainsMono Nerd Font" ]
  status=0; output="$(terminal_load nope 2>&1)" || status=$?
  [ "$status" -eq 1 ]
}
# The running terminal wins when an adapter exists for it: the greeting
# draws into, and the panel opens from, the window in front of the user. A
# terminal with no adapter (iterm2, in the fixtures directory) falls through
# to the primary key, then to the first of the list, then to the env alone.
@test "terminal_current prefers the running terminal with an adapter, then the config, then the env" {
  [ -z "$(terminal_current)" ]
  TERM_PROGRAM=iTerm.app; [ "$(terminal_current)" = "iterm2" ]
  toml_set "$NEKOSHELL_TOML" terminal kitty; [ "$(terminal_current)" = "kitty" ]
  toml_set_list "$NEKOSHELL_TOML" terminals bare fake
  [ "$(terminal_current)" = "kitty" ]
  toml_set "$NEKOSHELL_TOML" terminal ""; [ "$(terminal_current)" = "bare" ]
  FAKE_TERM=1 KITTY_WINDOW_ID=1; [ "$(terminal_current)" = "bare" ]
  # A terminal the fixtures do have an adapter for, detected by env, wins over
  # the primary key even when it is not configured.
  cp -R "$REPO_ROOT/tests/fixtures/terminals/fake" "$HOME/kitty-adapter"
  mkdir -p "$HOME/terminals"; cp -R "$REPO_ROOT/tests/fixtures/terminals/." "$HOME/terminals/"
  mv "$HOME/kitty-adapter" "$HOME/terminals/kitty"
  NEKOSHELL_TERMINALS_DIR="$HOME/terminals"
  toml_set "$NEKOSHELL_TOML" terminal fake
  [ "$(terminal_current)" = "kitty" ]
}
@test "terminal_configured_all reads the list, or the single key an older install wrote" {
  [ -z "$(terminal_configured_all)" ]
  toml_set "$NEKOSHELL_TOML" terminal fake
  [ "$(terminal_configured_all | tr '\n' ' ')" = "fake " ]
  toml_set_list "$NEKOSHELL_TOML" terminals bare fake
  [ "$(terminal_configured_all | tr '\n' ' ')" = "bare fake " ]
  terminal_is_configured bare
  status=0; terminal_is_configured kitty || status=$?
  [ "$status" -eq 1 ]
}
@test "terminal_expand_ids understands ids, comma lists, all and installed" {
  [ "$(terminal_expand_ids fake | tr '\n' ' ')" = "fake " ]
  [ "$(terminal_expand_ids fake,bare fake | tr '\n' ' ')" = "fake bare " ]
  [ "$(terminal_expand_ids all | tr '\n' ' ')" = "bare fake " ]
  [ "$(FAKE_TERM_INSTALLED=1 terminal_expand_ids installed | tr '\n' ' ')" = "fake " ]
  status=0; output="$(terminal_expand_ids fake,nope 2>&1)" || status=$?
  [ "$status" -eq 1 ]
  assert_contains "$output" "no terminal adapter named nope"
}
# Through `bare`, not `fake`: fake overrides terminal_panel so that the music
# tests can tell the panel path from the inline one, and an adapter that
# overrides the function cannot test the default it replaced.
@test "default terminal_panel uses a tmux popup inside tmux and runs inline outside" {
  terminal_load bare
  [ "$(terminal_name)" = "bare" ]
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  status=0; output="$(TMUX=1 terminal_panel echo hi 2>&1)" || status=$?
  assert_contains "$output" "tmux display-popup"
  unset TMUX
  status=0; output="$(terminal_panel echo hi 2>&1)" || status=$?
  [ "$output" = "hi" ]
}
