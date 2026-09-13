#!/usr/bin/env bash
# The terminal adapter contract. Every terminals/<id>/adapter.sh is sourced
# after this file and overrides what it supports. Functions:
#   terminal_name                       print the id
#   terminal_detect                     0 when the current shell runs in it
#   terminal_installed                  0 when the app is on this Mac
#   terminal_capabilities               words from: truecolor images background panel hotkey
#   terminal_font_name                  Nerd Font face to configure
#   terminal_apply FLAVOR               write font + colours into the terminal's config
#   terminal_background PATH|none [OPACITY]
#   terminal_panel CMD...               open CMD in a panel/overlay
#   terminal_panel_default CMD...       the fallback panel, for adapters to reuse
#   terminal_remove                     undo what terminal_apply wrote, on uninstall
#   terminal_doctor                     report rows (report is defined by the doctor)
# Needs log.sh. Source this file; do not execute it.

_terminal_unsupported() { log_fail "$1 is not supported by $(terminal_name)"; return 1; }
terminal_name()         { echo "unknown"; }
terminal_detect()       { return 1; }
terminal_installed()    { return 1; }
terminal_capabilities() { :; }
terminal_font_name()    { echo "JetBrainsMono NF"; }
terminal_apply()        { _terminal_unsupported "theme"; }
terminal_background()   { _terminal_unsupported "background"; }
# Nothing by default: an adapter that only reads the terminal's config has
# nothing to take back out.
terminal_remove()       { :; }
terminal_doctor()       { :; }
# Inside tmux a popup works everywhere; outside, run the command in this window.
# The body lives in terminal_panel_default so an adapter that overrides
# terminal_panel can still reach the fallback for the half it does not replace.
terminal_panel_default() {
  if [[ -n "${TMUX:-}" ]]; then tmux display-popup -E -w 80% -h 80% "$*"; else "$@"; fi
}
terminal_panel() { terminal_panel_default "$@"; }
