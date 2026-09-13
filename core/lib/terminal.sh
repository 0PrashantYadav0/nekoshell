#!/usr/bin/env bash
# Find and load terminal adapters. Needs paths.sh, log.sh, config.sh.
# Source this file; do not execute it.
#
# Two questions are asked about terminals and they have different answers.
# "Which terminals does this machine configure?" is terminal_configured_all:
# the `terminals` list in nekoshell.toml, which theme_apply, the doctor and
# uninstall walk in full. "Which terminal is this shell in?" is
# terminal_current: the one whose window the greeting draws into and the
# panel opens from, so it is the running terminal whenever it has an adapter.
NEKOSHELL_TERMINALS_DIR="${NEKOSHELL_TERMINALS_DIR:-$NEKOSHELL_ROOT/terminals}"
export NEKOSHELL_TERMINALS_DIR

terminal_all() {
  local d
  for d in "$NEKOSHELL_TERMINALS_DIR"/*/; do
    [[ -f "$d/adapter.sh" ]] && basename "$d"
  done
  return 0
}

terminal_has_adapter() { [[ -f "$NEKOSHELL_TERMINALS_DIR/$1/adapter.sh" ]]; }

# terminal_detect_env: the id of the terminal this shell runs in, from env. Status 1 when unknown.
terminal_detect_env() {
  if [[ -n "${KITTY_WINDOW_ID:-}" || "${TERM:-}" == "xterm-kitty" ]]; then
    echo kitty
    return 0
  fi
  if [[ -n "${GHOSTTY_RESOURCES_DIR:-}" || "${TERM_PROGRAM:-}" == "ghostty" ]]; then
    echo ghostty
    return 0
  fi
  if [[ -n "${WEZTERM_EXECUTABLE:-}" || "${TERM_PROGRAM:-}" == "WezTerm" ]]; then
    echo wezterm
    return 0
  fi
  case "${TERM_PROGRAM:-}" in
    iTerm.app)
      echo iterm2
      return 0
      ;;
    Apple_Terminal)
      echo terminal-app
      return 0
      ;;
    WarpTerminal)
      echo warp
      return 0
      ;;
  esac
  return 1
}

# terminal_load ID: define the adapter functions for ID. The contract comes
# from the checkout on purpose, whatever NEKOSHELL_TERMINALS_DIR points at:
# the defaults are core's, and only the adapters are allowed to vary.
terminal_load() {
  local id="$1"
  terminal_has_adapter "$id" || {
    log_fail "no terminal adapter named $id"
    return 1
  }
  # shellcheck source=/dev/null
  source "$NEKOSHELL_ROOT/terminals/adapter.sh"
  # shellcheck source=/dev/null
  source "$NEKOSHELL_TERMINALS_DIR/$id/adapter.sh"
}

# terminal_configured_all: the terminals nekoshell.toml records, one per
# line. The `terminals` list, or the single `terminal` key a v0.2.0 install
# wrote before the list existed.
terminal_configured_all() {
  local t any=0
  while IFS= read -r t; do
    [[ -n "$t" ]] || continue
    printf '%s\n' "$t"
    any=1
  done < <(config_list terminals 2>/dev/null || true)
  [[ "$any" == 1 ]] && return 0
  t="$(config_get terminal 2>/dev/null || true)"
  [[ -n "$t" ]] && printf '%s\n' "$t"
  return 0
}

# terminal_is_configured ID: true when ID is one of terminal_configured_all.
# A loop rather than `grep -q`, which leaves early and turns a match into a
# SIGPIPE on the producer under `set -o pipefail`.
terminal_is_configured() {
  local t found=1
  while IFS= read -r t; do
    [[ "$t" == "$1" ]] && found=0
  done < <(terminal_configured_all)
  return "$found"
}

# terminal_current: the terminal this shell acts on. The running terminal
# when an adapter exists for it, so images and panels match the window in
# front of the user even on a machine that configures several terminals;
# else the primary `terminal` key, else the first configured one, else
# whatever the environment says. Status 1 when there is nothing to say.
terminal_current() {
  local d t
  d="$(terminal_detect_env 2>/dev/null || true)"
  if [[ -n "$d" ]] && terminal_has_adapter "$d"; then
    echo "$d"
    return 0
  fi
  t="$(config_get terminal 2>/dev/null || true)"
  if [[ -n "$t" ]]; then
    echo "$t"
    return 0
  fi
  t="$(terminal_configured_all | head -n 1)"
  if [[ -n "$t" ]]; then
    echo "$t"
    return 0
  fi
  if [[ -n "$d" ]]; then
    echo "$d"
    return 0
  fi
  return 1
}

terminal_installed_all() {
  local id
  for id in $(terminal_all); do
    (terminal_load "$id" && terminal_installed) && echo "$id"
  done
  return 0
}

# terminal_expand_ids WORD...: the adapter ids WORD... names, one per line.
# `all` is every adapter, `installed` every adapter whose app is on this Mac,
# and anything else is ids, comma-separated or not. Duplicates are dropped.
# Status 1 with a log_fail for an id that has no adapter.
terminal_expand_ids() {
  local word id seen="" rc=0
  for word in "$@"; do
    case "$word" in
      all) for id in $(terminal_all); do seen="$seen $id"; done ;;
      installed) for id in $(terminal_installed_all); do seen="$seen $id"; done ;;
      *)
        for id in ${word//,/ }; do
          [[ -n "$id" ]] || continue
          if terminal_has_adapter "$id"; then
            seen="$seen $id"
          else
            log_fail "no terminal adapter named $id"
            rc=1
          fi
        done
        ;;
    esac
  done
  local out=""
  for id in $seen; do
    case " $out " in *" $id "*) continue ;; esac
    out="$out $id"
    printf '%s\n' "$id"
  done
  return "$rc"
}

# terminal_configure ID...: record ID... as configured terminals and apply
# the current theme to each. The primary `terminal` key becomes the running
# terminal when it is among them, else the first, unless it already names one
# of them. An adapter whose apply fails only warns, the same as theme_apply:
# the others still get their config, and the id stays recorded so the next
# `nekoshell terminal apply` tries again. Only an id with no adapter fails.
terminal_configure() {
  local id primary cur flavor rc=0
  [[ $# -gt 0 ]] || return 0
  flavor="$(theme_current)"
  for id in "$@"; do
    terminal_load "$id" || {
      rc=1
      continue
    }
    config_list_add terminals "$id"
    terminal_apply "$flavor" || log_warn "terminal $id: theme not applied"
  done
  primary="$(config_get terminal 2>/dev/null || true)"
  cur="$(terminal_detect_env 2>/dev/null || true)"
  if [[ -n "$cur" ]] && terminal_is_configured "$cur"; then
    config_set terminal "$cur"
  elif [[ -z "$primary" ]] || ! terminal_is_configured "$primary"; then
    config_set terminal "$1"
  fi
  return "$rc"
}
