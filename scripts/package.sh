#!/usr/bin/env bash
# package.sh: the release tarball and its checksum.
#
#   scripts/package.sh [--ref REF] [--out DIR]
#
# `git archive` of REF (default the tag for VERSION) with the prefix
# nekoshell-X.Y.Z/, honouring .gitattributes export-ignore, into DIR (default
# dist/), plus SHA256SUMS beside it. The release workflow attaches both to the
# GitHub Release, and the Homebrew formula pins the sha. Prints the tarball's
# size and entry count, and refuses to write SHA256SUMS if development files
# (tests/, scripts/) made it in anyway: the export-ignore lines in
# .gitattributes are the real fix, this is the tripwire.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$root"

ref=""
out="dist"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref)
      ref="${2:-}"
      shift 2
      ;;
    --out)
      out="${2:-}"
      shift 2
      ;;
    *)
      echo "usage: scripts/package.sh [--ref REF] [--out DIR]" >&2
      exit 2
      ;;
  esac
done
[[ -n "$ref" ]] || ref="v$(cat VERSION)"
git rev-parse -q --verify "$ref^{commit}" >/dev/null || {
  echo "no such ref: $ref" >&2
  exit 1
}
# VERSION as it is at REF, not in the working tree: the tarball's name has to
# match the tag being packaged even when the checkout has moved on.
version="$(git show "$ref:VERSION" | tr -d '[:space:]')"
name="nekoshell-$version"
mkdir -p "$out"
git archive --format=tar.gz --prefix="$name/" -o "$out/$name.tar.gz" "$ref"

bytes="$(wc -c <"$out/$name.tar.gz" | tr -d '[:space:]')"
# Capture the listing once: under `set -o pipefail`, `tar -tzf | grep -q`
# can have tar killed by SIGPIPE the moment grep exits early on a match,
# which pipefail then reports as a failure of the whole pipeline. Reading
# the listing into a variable first means the entry count and the tripwire
# below both work from the same already-complete output.
listing="$(tar -tzf "$out/$name.tar.gz")"
entries="$(printf '%s\n' "$listing" | wc -l | tr -d '[:space:]')"
kb="$((bytes / 1024))"
echo "$name.tar.gz: $kb KB, $entries entries"

if printf '%s\n' "$listing" | grep -qE "^$name/(tests|scripts)/"; then
  echo "the tarball carries development files; check the export-ignore lines in .gitattributes" >&2
  exit 1
fi

(cd "$out" && shasum -a 256 "$name.tar.gz" >SHA256SUMS)
cat "$out/SHA256SUMS"
