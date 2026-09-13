#!/usr/bin/env bash
# greet doctor: the two tools, and how long the greeting actually takes.

if command -v fastfetch >/dev/null 2>&1; then
  report ok "tool: fastfetch" "$(command -v fastfetch)"
else
  report fail "tool: fastfetch" "missing (nekoshell plugin add greet)"
fi

# Asked to draw something, not just to exist: a checkout whose python is gone
# or whose sprites never arrived answers `command -v` and nothing else.
if command -v pokemon-colorscripts >/dev/null 2>&1 && pokemon-colorscripts -r >/dev/null 2>&1; then
  report ok "pokemon-colorscripts" "$(command -v pokemon-colorscripts)"
else
  report fail "pokemon-colorscripts" "missing or broken (nekoshell plugin add greet)"
fi

# This runs on every new shell, so it has a budget. Measured through a pty,
# because the greeting says nothing at all without one.
#
# Every check that silences the greeting is cleared for the probe, and the
# list has to be the whole list: the doctor is run from a real shell, which
# may well be one inside tmux, inside the panel, or over SSH, and any one of
# those left set makes the greeting exit 0 with nothing to time — a "could
# not measure" that says nothing about the greeting and everything about
# where the doctor was run from. NEKOSHELL_GREET_MODE is cleared too, so what
# is timed is the automatic path a new shell actually takes.
#
# Real art ends on an unterminated colour reset, so the timing line arrives
# with an escape sequence glued to its front: match the tail of the line, not
# the whole of it.
if command -v fastfetch >/dev/null 2>&1; then
  # `|| true` inside, because the hook runs under `set -o pipefail`: a machine
  # with no usable `script` must leave the row unmeasured, not take the whole
  # doctor hook down with it.
  gr_ms="$({ NEKOSHELL_SEED=1 NEKOSHELL_GREET_TIME=1 NEKOSHELL_NO_GREET='' CLAUDECODE='' TMUX='' \
    SSH_CONNECTION='' NEKOSHELL_PANEL='' NEKOSHELL_GREET_MODE='' \
    script -q /dev/null "$PLUGIN_DIR/bin/nekoshell-greet" </dev/null 2>/dev/null || true; } \
    | tr -d '\r' | sed -n 's/^.*greet: \([0-9][0-9]*\) ms$/\1/p')"
  if [[ -z "$gr_ms" ]]; then
    report warn "greet time" "could not measure"
  elif ((gr_ms <= 150)); then
    report ok "greet time" "${gr_ms} ms"
  else
    report warn "greet time" "${gr_ms} ms (budget 150)"
  fi
fi

true
