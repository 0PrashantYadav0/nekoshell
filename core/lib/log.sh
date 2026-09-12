#!/usr/bin/env bash
# Printing helpers shared by install.sh, uninstall.sh and bin/ scripts.
# Source this file; do not execute it.

if [[ -t 1 ]]; then
  _NK_MAUVE=$'\033[38;2;203;166;247m'
  _NK_GREEN=$'\033[38;2;166;227;161m'
  _NK_YELLOW=$'\033[38;2;249;226;175m'
  _NK_RED=$'\033[38;2;243;139;168m'
  _NK_DIM=$'\033[38;2;108;112;134m'
  _NK_RESET=$'\033[0m'
else
  _NK_MAUVE=""; _NK_GREEN=""; _NK_YELLOW=""; _NK_RED=""; _NK_DIM=""; _NK_RESET=""
fi

NEKOSHELL_DRY_RUN="${NEKOSHELL_DRY_RUN:-0}"

log_info() { printf '%s..%s %s\n' "$_NK_DIM" "$_NK_RESET" "$*"; }
log_ok()   { printf '%sok%s   %s\n' "$_NK_GREEN" "$_NK_RESET" "$*"; }
log_warn() { printf '%swarn%s %s\n' "$_NK_YELLOW" "$_NK_RESET" "$*"; }
log_fail() { printf '%sfail%s %s\n' "$_NK_RED" "$_NK_RESET" "$*" >&2; }
log_step() { printf '\n%s[%s/%s]%s %s\n' "$_NK_MAUVE" "$1" "$2" "$_NK_RESET" "$3"; }
log_head() { printf '\n%s::%s %s\n' "$_NK_MAUVE" "$_NK_RESET" "$*"; }

# run CMD ARGS...: print the command, then execute it unless NEKOSHELL_DRY_RUN=1.
run() {
  printf '%s$ %s%s\n' "$_NK_DIM" "$*" "$_NK_RESET"
  if [[ "$NEKOSHELL_DRY_RUN" == "1" ]]; then
    return 0
  fi
  "$@"
}

# run_quiet CMD ARGS...: run, with the command's own stdout thrown away. The
# command line is still printed, so a log still says what happened; only the
# chatter a successful run produces is dropped. stderr is kept, because a
# command that is failing has to be able to say so.
run_quiet() {
  printf '%s$ %s%s\n' "$_NK_DIM" "$*" "$_NK_RESET"
  if [[ "$NEKOSHELL_DRY_RUN" == "1" ]]; then
    return 0
  fi
  "$@" >/dev/null
}

# confirm PROMPT: a y/N read from stdin, shared by install.sh and
# uninstall.sh. A closed or absent stdin reads as empty, which this treats
# as "no": nothing that calls confirm is destructive enough to default the
# other way.
confirm() {
  printf '%s [y/N] ' "$1"
  local reply=""
  read -r reply || true
  [[ "$reply" == y* || "$reply" == Y* ]]
}
