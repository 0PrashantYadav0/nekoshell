#!/usr/bin/env bash
# greet doctor: fastfetch, every enabled art provider, and how long the
# greeting actually takes.

if command -v fastfetch >/dev/null 2>&1; then
  report ok "tool: fastfetch" "$(command -v fastfetch)"
else
  report fail "tool: fastfetch" "missing (nekoshell plugin add greet)"
fi

# One row per enabled art provider, asked to draw rather than just to exist:
# a pack that never arrived answers `-x` and nothing else. A sprite provider
# is asked for its sprite, an image provider for its picture; one that ships
# both is asked for the sprite, which draws in any terminal.
_greet_any=0
for _greet_p in $(plugin_enabled_all); do
  _greet_art=""
  for _greet_f in greet-art greet-image; do
    if [[ -x "$(plugin_dir "$_greet_p")/$_greet_f" ]]; then
      _greet_art="$(plugin_dir "$_greet_p")/$_greet_f"
      break
    fi
  done
  [[ -n "$_greet_art" ]] || continue
  _greet_any=1
  if PLUGIN_NAME="$_greet_p" PLUGIN_DIR="$(plugin_dir "$_greet_p")" "$_greet_art" >/dev/null 2>&1; then
    report ok "art: $_greet_p" "draws"
  else
    report fail "art: $_greet_p" "nothing to draw (nekoshell plugin add $_greet_p)"
  fi
done
[[ "$_greet_any" == 1 ]] || report warn "art" "no art provider enabled (run: nekoshell plugin add pokemon)"

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
    SSH_CONNECTION='' NEKOSHELL_PANEL='' NEKOSHELL_GREET_MODE='' NEKOSHELL_GREET_ART='' \
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
