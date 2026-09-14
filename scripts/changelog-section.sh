#!/usr/bin/env bash
# changelog-section.sh: the body of one version's section of CHANGELOG.md,
# which the release workflow uses as the GitHub Release notes.
#
#   scripts/changelog-section.sh X.Y.Z [FILE]
#
# Matches "## X.Y.Z" followed by a space or the end of the line, so 0.2.0
# never matches 0.2.0-rc1 or 10.2.0. Exit 1 when there is no such section.
set -euo pipefail
version="${1:-}"
file="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)/CHANGELOG.md}"
[[ -n "$version" ]] || {
  echo "usage: scripts/changelog-section.sh X.Y.Z [FILE]" >&2
  exit 2
}
body="$(awk -v v="$version" '
  /^## / {
    if (on) exit
    if ($0 == "## " v || index($0, "## " v " ") == 1) { on = 1; next }
  }
  on { print }
' "$file" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"
# Leading blank lines: awk starts printing right after the heading, which is
# always followed by one.
body="$(printf '%s\n' "$body" | sed '/./,$!d')"
[[ -n "$body" ]] || {
  echo "no section for $version in $file" >&2
  exit 1
}
printf '%s\n' "$body"
