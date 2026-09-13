#!/usr/bin/env bash
terminal_name() { echo fake; }
terminal_detect() { [[ "${FAKE_TERM:-}" == "1" ]]; }
terminal_installed() { [[ "${FAKE_TERM_INSTALLED:-1}" == "1" ]]; }
terminal_capabilities() { echo "truecolor images background panel"; }
terminal_apply() { echo "fake apply $1" >>"$NEKOSHELL_CACHE/hooks.log"; }
terminal_doctor() { report ok "fake terminal" "present"; }
# Overrides the default so a test can tell the panel path from the inline one:
# the default runs the command in this window outside tmux, which is exactly
# what running it inline looks like. The marker makes the two distinguishable.
# tests/fixtures/terminals/bare exists to exercise the default itself.
terminal_panel() {
  echo "fake panel: $*"
  "$@"
}
