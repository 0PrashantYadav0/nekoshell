#!/usr/bin/env bash
# Find and load terminal adapters. Needs paths.sh, log.sh, config.sh.
NEKOSHELL_TERMINALS_DIR="${NEKOSHELL_TERMINALS_DIR:-$NEKOSHELL_ROOT/terminals}"
export NEKOSHELL_TERMINALS_DIR

terminal_all() {
  local d
  for d in "$NEKOSHELL_TERMINALS_DIR"/*/; do
    [[ -f "$d/adapter.sh" ]] && basename "$d"
  done
}

# terminal_detect_env: the id of the terminal this shell runs in, from env. Status 1 when unknown.
terminal_detect_env() {
  if [[ -n "${KITTY_WINDOW_ID:-}" || "${TERM:-}" == "xterm-kitty" ]]; then echo kitty; return 0; fi
  if [[ -n "${GHOSTTY_RESOURCES_DIR:-}" || "${TERM_PROGRAM:-}" == "ghostty" ]]; then echo ghostty; return 0; fi
  if [[ -n "${WEZTERM_EXECUTABLE:-}" || "${TERM_PROGRAM:-}" == "WezTerm" ]]; then echo wezterm; return 0; fi
  case "${TERM_PROGRAM:-}" in
    iTerm.app) echo iterm2; return 0 ;;
    Apple_Terminal) echo terminal-app; return 0 ;;
  esac
  return 1
}

# terminal_load ID: define the adapter functions for ID.
terminal_load() {
  local id="$1"
  [[ -f "$NEKOSHELL_TERMINALS_DIR/$id/adapter.sh" ]] || { log_fail "no terminal adapter named $id"; return 1; }
  # shellcheck source=/dev/null
  source "$NEKOSHELL_ROOT/terminals/adapter.sh"
  # shellcheck source=/dev/null
  source "$NEKOSHELL_TERMINALS_DIR/$id/adapter.sh"
}

terminal_current() {
  local t
  t="$(config_get terminal 2>/dev/null || true)"
  [[ -n "$t" ]] && { echo "$t"; return 0; }
  terminal_detect_env
}

terminal_installed_all() {
  local id
  for id in $(terminal_all); do
    ( terminal_load "$id" && terminal_installed ) && echo "$id"
  done
  return 0
}
