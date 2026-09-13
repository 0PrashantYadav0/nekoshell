#!/usr/bin/env bash
# check-commit-msg.sh: is this commit message one the repository accepts?
#
#   scripts/check-commit-msg.sh FILE          check the message in FILE (the commit-msg hook)
#   scripts/check-commit-msg.sh --range A..B  check every commit in the range (CI, on a pull request)
#
# The rules, the same ones CONTRIBUTING.md states:
#   1. The subject is a conventional commit: type(scope)?!?: description, with
#      the type one of feat fix docs style refactor perf test build ci chore
#      revert, a lower-case description, no trailing full stop, 72 characters
#      at most.
#   2. A body, when present, is separated from the subject by a blank line.
#   3. The message ends with a Co-Authored-By trailer when it was written with
#      an AI assistant (checked only for presence of a well-formed trailer if
#      the word "Co-Authored-By" appears at all).
# Merge commits, reverts git wrote itself, and fixup!/squash! commits are
# accepted as they are.
set -euo pipefail

types='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'
subject_re="^($types)(\([a-z0-9][a-z0-9._/-]*\))?!?: [^A-Z].*[^.]$"

check_message() {
  local msg="$1" subject rc=0 line n=0 blank_ok=1
  subject="$(printf '%s\n' "$msg" | sed -n '1p')"
  case "$subject" in
    "Merge "* | "Revert \""* | "fixup! "* | "squash! "*) return 0 ;;
  esac
  if ! [[ "$subject" =~ $subject_re ]]; then
    echo "subject is not a conventional commit: '$subject'" >&2
    echo "expected: type(scope): lower-case description   (types: ${types//|/ })" >&2
    rc=1
  fi
  if [[ ${#subject} -gt 72 ]]; then
    echo "subject is ${#subject} characters; keep it to 72" >&2
    rc=1
  fi
  while IFS= read -r line; do
    n=$((n + 1))
    [[ "$n" -eq 2 ]] || continue
    [[ -z "$line" ]] || blank_ok=0
  done <<<"$msg"
  if [[ "$blank_ok" == 0 ]]; then
    echo "the second line must be blank (subject, blank line, body)" >&2
    rc=1
  fi
  if printf '%s\n' "$msg" | grep -qi 'co-authored-by' \
    && ! printf '%s\n' "$msg" | grep -qE '^Co-Authored-By: .+ <[^>]+>$'; then
    echo "the Co-Authored-By trailer must read: Co-Authored-By: Name <email>" >&2
    rc=1
  fi
  return "$rc"
}

# strip_comments FILE: the message without git's commented lines and without
# the trailing blank lines git strips itself.
strip_comments() {
  grep -v '^#' "$1" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
}

case "${1:-}" in
  --range)
    range="${2:-}"
    [[ -n "$range" ]] || {
      echo "usage: $0 --range A..B" >&2
      exit 2
    }
    failed=0
    for sha in $(git rev-list --no-merges "$range"); do
      msg="$(git log -1 --format=%B "$sha")"
      if ! check_message "$msg"; then
        echo "  in commit $(git log -1 --format='%h %s' "$sha")" >&2
        failed=1
      fi
    done
    exit "$failed"
    ;;
  -h | --help | "")
    sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    check_message "$(strip_comments "$1")"
    ;;
esac
