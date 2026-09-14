#!/usr/bin/env bash
# render-formula.sh: the Homebrew formula for one release, on stdout.
#
#   scripts/render-formula.sh --version X.Y.Z --sha256 HEX [--url URL]
#
# Fills @URL@ and @SHA256@ in packaging/homebrew/nekoshell.rb.tmpl. --version
# builds the default url; the formula takes its version from that url, so a
# version stanza of its own would only be something for brew audit to flag.
# The release workflow writes the result to Formula/nekoshell.rb in the tap;
# rendering the whole file, rather than patching two lines of the tap's copy
# with sed, keeps the template here the only source of truth.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
version="" sha="" url=""
usage() { echo "usage: scripts/render-formula.sh --version X.Y.Z --sha256 HEX [--url URL]" >&2; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      version="${2:-}"
      shift 2
      ;;
    --sha256)
      sha="${2:-}"
      shift 2
      ;;
    --url)
      url="${2:-}"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  usage
  exit 2
}
[[ "$sha" =~ ^[0-9a-f]{64}$ ]] || {
  echo "sha256 must be 64 lower-case hex characters" >&2
  exit 2
}
[[ -n "$url" ]] || url="https://github.com/0PrashantYadav0/nekoshell/releases/download/v$version/nekoshell-$version.tar.gz"
sed -e "s|@URL@|$url|g" -e "s|@SHA256@|$sha|g" \
  "$root/packaging/homebrew/nekoshell.rb.tmpl"
