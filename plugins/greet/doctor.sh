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
# because the greeting says nothing at all without one, and with the checks
# that would otherwise silence it cleared. Real art ends on an unterminated
# colour reset, so the timing line arrives with an escape sequence glued to
# its front: match the tail of the line, not the whole of it.
if command -v fastfetch >/dev/null 2>&1; then
  gr_ms="$(NEKOSHELL_SEED=1 NEKOSHELL_GREET_TIME=1 NEKOSHELL_NO_GREET='' CLAUDECODE='' TMUX='' \
    script -q /dev/null "$PLUGIN_DIR/bin/nekoshell-greet" </dev/null 2>/dev/null \
    | tr -d '\r' | sed -n 's/^.*greet: \([0-9][0-9]*\) ms$/\1/p')"
  if [[ -z "$gr_ms" ]]; then
    report warn "greet time" "could not measure"
  elif (( gr_ms <= 150 )); then
    report ok "greet time" "${gr_ms} ms"
  else
    report warn "greet time" "${gr_ms} ms (budget 150)"
  fi
fi

true
