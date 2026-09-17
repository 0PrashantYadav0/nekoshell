#!/usr/bin/env bash
# anime install: fetch the picture pack, pinned, and shrink it once.
#
# The pack is a git repository of PNG stills, 185 MB at full size. It is
# fetched as GitHub's archive of one commit rather than cloned: a commit's
# tree is what it is, so the commit id is the pin, and there is no 185 MB
# .git to keep afterwards. (The archive's gzip header is not stable across
# GitHub's servers, so a checksum of the tarball would not be either; the
# commit id is the integrity here.)
#
# Every picture is shrunk with sips before it is kept: fastfetch decodes the
# picture on every shell start, a 3500 px scan costs more than the whole
# 150 ms greeting budget, and 640 px on the long side is more than any
# terminal cell box shows. What stays under ~/.local/share is under 20 MB. The
# pixel size of each shrunk picture is written down beside it, so greet-image
# never opens a file to learn its proportions.
#
# Nothing here aborts `plugin add`: offline, or a picture sips cannot read,
# leaves what is there and warns, and the doctor's own row is where a missing
# pack is reported.

ANIME_SHA="2619f112c2d7fc1514f098b6a9fc16fe20ff5124"
ANIME_URL="https://github.com/thunder-blaze/FastfetchPngs/archive/$ANIME_SHA.tar.gz"
ANIME_DIR="$HOME/.local/share/fastfetch-pngs"
ANIME_PX=640

# anime_prepare SRC OUT LIST: shrink every PNG at the top of SRC into OUT and
# append "name width height" for each to LIST. Leaves how many were kept in
# an_kept; a warning goes to the log, so the count cannot be its output.
anime_prepare() {
  local src="$1" out="$2" list="$3" f name size kept=0 failed=0
  an_kept=0
  for f in "$src"/*.png; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f")"
    if sips -Z "$ANIME_PX" "$f" --out "$out/$name" >/dev/null 2>&1; then
      size="$(sips -g pixelWidth -g pixelHeight "$out/$name" 2>/dev/null \
        | awk '/pixelWidth:/ { w = $2 } /pixelHeight:/ { h = $2 } END { if (w > 0 && h > 0) print w, h }')"
      if [[ -n "$size" ]]; then
        printf '%s %s\n' "$name" "$size" >>"$list"
        kept=$((kept + 1))
        continue
      fi
      rm -f "$out/$name"
    fi
    failed=$((failed + 1))
  done
  [[ "$failed" -eq 0 ]] || log_warn "$PLUGIN_NAME: $failed of $((kept + failed)) pictures could not be shrunk and were left out"
  an_kept="$kept"
}

if [[ -f "$ANIME_DIR/.nekoshell-version" && "$(cat "$ANIME_DIR/.nekoshell-version")" == "$ANIME_SHA" ]]; then
  log_info "$PLUGIN_NAME: the pictures at ${ANIME_SHA:0:7} are already here"
elif ! command -v sips >/dev/null 2>&1; then
  log_warn "$PLUGIN_NAME: sips is missing, so the pictures cannot be prepared; the greeting will skip them"
else
  an_tmp="$(mktemp -d "${TMPDIR:-/tmp}/nekoshell-anime.XXXXXX")"
  if run curl -fsSL -o "$an_tmp/pngs.tar.gz" "$ANIME_URL"; then
    if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
      : # nothing was downloaded
    else
      mkdir -p "$an_tmp/src" "$an_tmp/out"
      # The archive's entries start with FastfetchPngs-<commit>/.
      if run tar -xzf "$an_tmp/pngs.tar.gz" -C "$an_tmp/src" --strip-components 1; then
        log_info "$PLUGIN_NAME: shrinking the pictures to $ANIME_PX px with sips"
        anime_prepare "$an_tmp/src" "$an_tmp/out" "$an_tmp/list"
        if [[ "$an_kept" -gt 0 ]]; then
          run rm -rf "$ANIME_DIR"
          run mkdir -p "$(dirname "$ANIME_DIR")"
          run mv "$an_tmp/out" "$ANIME_DIR"
          sort "$an_tmp/list" >"$ANIME_DIR/.nekoshell-list.txt"
          printf '%s\n' "$ANIME_SHA" >"$ANIME_DIR/.nekoshell-version"
          log_info "$PLUGIN_NAME: $an_kept pictures in $ANIME_DIR"
        else
          log_warn "$PLUGIN_NAME: could not prepare any of the anime pictures; keeping what is there"
        fi
      else
        log_warn "$PLUGIN_NAME: could not unpack the anime pictures; keeping what is there"
      fi
    fi
  else
    log_warn "$PLUGIN_NAME: could not download the anime pictures; the greeting will skip them"
  fi
  rm -rf "$an_tmp"
fi

true
