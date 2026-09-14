#!/usr/bin/env bash
# release.sh: cut a release from main. One command, then one push.
#
#   scripts/release.sh X.Y.Z [--dry-run]
#
# Writes VERSION, turns the "## X.Y.Z (unreleased)" CHANGELOG heading into a
# dated one, commits "chore(release): X.Y.Z" signed off, and tags vX.Y.Z. The
# push is left to you: `git push origin main --follow-tags` starts
# .github/workflows/release.yml, which builds the tarball, publishes the
# GitHub Release and updates the Homebrew tap. --dry-run prints what would
# happen. NEKOSHELL_RELEASE_BRANCH overrides main (the tests use it).
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$root"

version="${1:-}"
dry=0
[[ "${2:-}" == "--dry-run" ]] && dry=1
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "usage: scripts/release.sh X.Y.Z [--dry-run]" >&2
  exit 2
}
want="${NEKOSHELL_RELEASE_BRANCH:-main}"
branch="$(git rev-parse --abbrev-ref HEAD)"
[[ "$branch" == "$want" ]] || {
  echo "release from $want, not $branch" >&2
  exit 1
}
[[ -z "$(git status --porcelain)" ]] || {
  echo "the working tree is not clean; commit or stash first" >&2
  exit 1
}
if git rev-parse -q --verify "refs/tags/v$version" >/dev/null; then
  echo "tag v$version already exists" >&2
  exit 1
fi
heading="## $version (unreleased)"
grep -qF "$heading" CHANGELOG.md || {
  echo "CHANGELOG.md has no '$heading' section; write the notes first" >&2
  exit 1
}
today="$(date -u +%Y-%m-%d)"
if [[ "$dry" == 1 ]]; then
  echo "would write VERSION $version"
  echo "would date CHANGELOG.md: $heading -> ## $version - $today"
  echo "would commit chore(release): $version and tag v$version"
  exit 0
fi
printf '%s\n' "$version" >VERSION
# Never `sed -i`: macOS and GNU sed disagree about its argument. The result is
# copied back rather than moved, so CHANGELOG.md keeps its own mode instead of
# inheriting mktemp's 0600.
tmp="$(mktemp)"
sed "s/^## $version (unreleased)$/## $version - $today/" CHANGELOG.md >"$tmp"
cat "$tmp" >CHANGELOG.md && rm -f "$tmp"
# The guard above matches the heading anywhere on the line; this sed only
# matches a whole line. A heading with trailing whitespace passes the one and
# not the other, so check the rewrite really happened before committing it.
grep -qE "^## $version - [0-9]{4}-[0-9]{2}-[0-9]{2}$" CHANGELOG.md || {
  echo "could not date the '$heading' heading in CHANGELOG.md" >&2
  exit 1
}
git add VERSION CHANGELOG.md
git commit -q -s -m "chore(release): $version"
git tag -a "v$version" -m "nekoshell $version"
echo "tagged v$version"
echo "publish with: git push origin main --follow-tags"
