#!/usr/bin/env bash
# anime install: fetch the pinned release of anime-colorscripts.
#
# The git tree of that project holds no sprites (its build scrapes them from
# the web), so the release tarball is the artefact, checked against a
# recorded checksum. Nothing here aborts `plugin add`: offline, or a download
# that does not match, leaves what is there and warns, and the doctor's own
# row is where a missing pack is reported.

ANIME_VERSION="v1.1.3"
ANIME_URL="https://github.com/juanlouisr/anime-colorscripts/releases/download/$ANIME_VERSION/anime-colorscripts.tar.gz"
# The sha256 of that asset, taken on 2026-09-13. Tests point
# NEKOSHELL_ANIME_SHA256 at a tarball of their own.
ANIME_SHA256="${NEKOSHELL_ANIME_SHA256:-7e7ad31618fa292875588e2cb1f0e99ff42bac7fcffc615697aafcf34e1db3f5}"
ANIME_DIR="$HOME/.local/share/anime-colorscripts"

# anime_write_list: the sprites that fit next to the stats, one name per line
# in .nekoshell-list.txt. Some of the pack's sprites are 250 columns wide;
# 80 leaves room for fastfetch's rows on a 120-column window. Measured once
# here, so greet-art never has to open 247 files on a shell start-up.
anime_write_list() {
  python3 - "$ANIME_DIR" <<'PY'
import glob, os, re, sys
base = sys.argv[1]
esc = re.compile(r"\x1b\[[0-9;]*m")
names = []
for f in sorted(glob.glob(os.path.join(base, "colorscripts", "*.txt"))):
    text = open(f, encoding="utf-8", errors="replace").read()
    width = max((len(esc.sub("", line)) for line in text.split("\n")), default=0)
    if width <= 80:
        names.append(os.path.basename(f)[:-4])
tmp = os.path.join(base, ".nekoshell-list.txt.tmp")
with open(tmp, "w", encoding="utf-8") as out:
    out.write("".join(n + "\n" for n in names))
os.replace(tmp, os.path.join(base, ".nekoshell-list.txt"))
PY
}

if [[ -f "$ANIME_DIR/.nekoshell-version" && "$(cat "$ANIME_DIR/.nekoshell-version")" == "$ANIME_VERSION" ]]; then
  log_info "$PLUGIN_NAME: anime-colorscripts $ANIME_VERSION is already here"
  # A pack unpacked before the list existed gets one now.
  [[ -s "$ANIME_DIR/.nekoshell-list.txt" || "${NEKOSHELL_DRY_RUN:-0}" == "1" ]] || anime_write_list
else
  an_tmp="$(mktemp -d "${TMPDIR:-/tmp}/nekoshell-anime.XXXXXX")"
  if run curl -fsSL -o "$an_tmp/anime.tar.gz" "$ANIME_URL"; then
    if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
      : # nothing was downloaded
    elif [[ "$(shasum -a 256 "$an_tmp/anime.tar.gz" | cut -d' ' -f1)" != "$ANIME_SHA256" ]]; then
      log_warn "$PLUGIN_NAME: the download does not match the recorded checksum; keeping what is there"
    else
      run rm -rf "$ANIME_DIR"
      run mkdir -p "$ANIME_DIR"
      # The tarball's entries start with ./anime-colorscripts/.
      run tar -xzf "$an_tmp/anime.tar.gz" -C "$ANIME_DIR" --strip-components 2
      anime_write_list
      printf '%s\n' "$ANIME_VERSION" >"$ANIME_DIR/.nekoshell-version"
    fi
  else
    log_warn "$PLUGIN_NAME: could not download anime-colorscripts; the greeting will skip it"
  fi
  rm -rf "$an_tmp"
fi

true
