# Spotify Search Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `nekoshell spotify search [QUERY]` (alias `sps`): a live fzf search bar over Spotify that plays the selection on the active device.

**Architecture:** `plugins/spotify/bin/nekoshell-spotify-search` has three modes: `--rows QUERY` prints typed rows (label, type, id) from `spotify_player search`, `--play ROW` starts playback, and the default runs fzf with `--disabled` (so fzf never filters the server's answers) and a `change:reload` binding that calls `--rows` with the typed query. `cmd/spotify.sh` gains the `search` subcommand; `plugin.zsh` the alias.

**Tech Stack:** bash 3.2, python3 (JSON flattening), fzf ≥ 0.36 (`reload` on `change`, `--disabled`), spotify_player 0.25.x CLI.

**Spec:** `docs/superpowers/specs/2026-09-13-art-providers-and-plugins-design.md`, section 4.

## Global Constraints

- As the other plans. Branch: `feat/spotify-search`.
- The command never hangs: an upstream parse error is reported in one line, status 1.
- Shows and episodes are not playable through the CLI and are not listed.

---

### Task 1: Rows and play, tested through the fakes

**Files:**

- Create: `plugins/spotify/bin/nekoshell-spotify-search`, `tests/fixtures/spotify-search.json`
- Modify: `tests/fakes/spotify_player` (`search` prints the fixture, `playback` echoes; `FAKE_SPOTIFY_SEARCH_FAIL=1` prints spotify_player's real parse error and exits 1; `FAKE_SPOTIFY_NO_DEVICE=1` makes `playback start` fail with `No active device found`), `tests/fakes/fzf` (`FAKE_FZF_PICK=N` prints the Nth line of stdin; otherwise the old echo)
- Test: `tests/plugins/spotify.bats`

**Interfaces:**

- Produces: rows of the form `ICON label<TAB>type<TAB>id` where ICON is `♪` track, `▣` album, `♩` artist, `≡` playlist; an error row `! MESSAGE<TAB>error<TAB>-` when the search fails.

- [ ] **Step 1: The fixture**

Run a real search once (`spotify_player search hello | python3 -m json.tool | head -120`) and write `tests/fixtures/spotify-search.json` with two tracks, one album, one artist and one playlist in the real shape (`tracks[].name/artists[].name/album.name/id`, `albums[].name/artists/id`, `artists[].name/id`, `playlists[].name/owner/id`; check whether `owner` is `{"name": ...}` or `{"display_name": ...}` and keep that).

- [ ] **Step 2: Failing tests**

```bash
@test "search --rows flattens tracks, albums, artists and playlists into typed rows" {
  run "$P/bin/nekoshell-spotify-search" --rows "hello"
  [ "$status" -eq 0 ]
  assert_matches "$output" $'^♪ [^\t]+ · [^\t]+ · [^\t]+\ttrack\t[A-Za-z0-9]+'
  assert_matches "$output" $'▣ [^\t]+ · [^\t]+\talbum\t'
  assert_matches "$output" $'♩ [^\t]+\tartist\t'
  assert_matches "$output" $'≡ [^\t]+ · [^\t]+\tplaylist\t'
  assert_not_contains "$output" "episode"
}

@test "search --rows with no query prints nothing" {
  run "$P/bin/nekoshell-spotify-search" --rows ""
  [ -z "$output" ]
}

@test "an upstream parse error becomes one error row, status 1" {
  FAKE_SPOTIFY_SEARCH_FAIL=1 run "$P/bin/nekoshell-spotify-search" --rows "daft punk"
  [ "$status" -eq 1 ]
  assert_matches "$output" $'^! spotify_player could not read Spotify.s answer.*\terror\t-$'
}

@test "search --play starts a track by id, a context by type" {
  run "$P/bin/nekoshell-spotify-search" --play $'♪ Hello · A · B\ttrack\tT1'
  assert_contains "$output" "spotify_player playback start track --id T1"
  assert_contains "$output" "playing: ♪ Hello · A · B"
  run "$P/bin/nekoshell-spotify-search" --play $'≡ Mix · Spotify\tplaylist\tP1'
  assert_contains "$output" "spotify_player playback start context --id P1 playlist"
}

@test "search --play with no active device says to start the player" {
  FAKE_SPOTIFY_NO_DEVICE=1 run "$P/bin/nekoshell-spotify-search" --play $'♪ Hello · A · B\ttrack\tT1'
  [ "$status" -eq 1 ]
  assert_contains "$output" "no Spotify device is active; start nekoshell music first"
}

@test "search with a query opens fzf on the rows and plays the pick" {
  FAKE_FZF_PICK=1 run "$P/bin/nekoshell-spotify-search" "hello"
  [ "$status" -eq 0 ]
  assert_contains "$output" "spotify_player playback start track --id"
}

@test "search without fzf falls back to a numbered menu" {
  run bash -c "printf '2\n' | PATH=/usr/bin:/bin:$REPO_ROOT/tests/fakes-nofzf $P/bin/nekoshell-spotify-search hello"
  assert_contains "$output" "1) ♪"
  assert_contains "$output" "spotify_player playback start"
}

@test "nekoshell spotify search and the sps alias reach the program" {
  "$NK" plugin add spotify >/dev/null
  FAKE_FZF_PICK=1 run "$NK" spotify search hello
  assert_contains "$output" "playback start"
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  run zsh -o NO_GLOBAL_RCS -ic 'alias sps; exit 0'
  assert_contains "$output" "nekoshell spotify search"
}
```

(`tests/fakes-nofzf/` holds links to every fake except fzf; create it with a loop and commit it.)

- [ ] **Step 3: Run to verify they fail**

- [ ] **Step 4: The program**

```bash
#!/usr/bin/env bash
# nekoshell-spotify-search: a search bar over Spotify in the shell.
#
#   nekoshell-spotify-search [QUERY]      fzf: the list refills as you type; Enter plays
#   nekoshell-spotify-search --rows QUERY  the rows for QUERY (what fzf reloads with)
#   nekoshell-spotify-search --play ROW    play one row
#
# Rows are "ICON label<TAB>type<TAB>id": ♪ track, ▣ album, ♩ artist,
# ≡ playlist. Shows and episodes are left out: the CLI cannot start them.
set -uo pipefail

self="${BASH_SOURCE[0]}"
[[ "$self" == /* ]] || self="$(cd "$(dirname "$self")" && pwd -P)/$(basename "$self")"

# rows QUERY: one row per result. spotify_player 0.25.1 fails to parse some
# of Spotify's answers (a null where it expects a boolean); that comes back
# as one error row so the bar can show it, and status 1.
rows() {
  local q="$1" json
  [[ -n "$q" ]] || return 0
  if ! json="$(spotify_player search "$q" 2>&1)"; then
    printf '! spotify_player could not read Spotify'"'"'s answer for "%s" (try other words)\terror\t-\n' "$q"
    return 1
  fi
  printf '%s' "$json" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except ValueError:
    print("! spotify_player returned something that is not JSON\terror\t-")
    sys.exit(1)
def names(x): return ", ".join(a.get("name", "") for a in x.get("artists", []))
for t in d.get("tracks", []):
    print("♪ %s · %s · %s\ttrack\t%s" % (t.get("name", ""), names(t), t.get("album", {}).get("name", ""), t.get("id", "")))
for a in d.get("albums", []):
    print("▣ %s · %s\talbum\t%s" % (a.get("name", ""), names(a), a.get("id", "")))
for a in d.get("artists", []):
    print("♩ %s\tartist\t%s" % (a.get("name", ""), a.get("id", "")))
for p in d.get("playlists", []):
    owner = p.get("owner") or {}
    print("≡ %s · %s\tplaylist\t%s" % (p.get("name", ""), owner.get("name") or owner.get("display_name") or "", p.get("id", "")))
'
}

# play ROW: start playback for the row on the active device.
play() {
  local row="$1" label type id
  IFS=$'\t' read -r label type id <<<"$row"
  [[ -n "$id" && "$type" != "error" ]] || return 0
  local ok=1
  if [[ "$type" == "track" ]]; then
    spotify_player playback start track --id "$id" || ok=0
  else
    spotify_player playback start context --id "$id" "$type" || ok=0
  fi
  if [[ "$ok" == 0 ]]; then
    echo "no Spotify device is active; start nekoshell music first" >&2
    return 1
  fi
  printf 'playing: %s\n' "$label"
}

case "${1:-}" in
  --rows)
    rows "${2:-}"
    exit $?
    ;;
  --play)
    play "${2:-}"
    exit $?
    ;;
  -h | --help)
    sed -n '2,10p' "$self" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac

query="$*"
if command -v fzf >/dev/null 2>&1; then
  pick="$( { [[ -n "$query" ]] && rows "$query"; true; } | fzf --disabled --delimiter $'\t' --with-nth 1 \
    --prompt 'Spotify › ' --query "$query" --header 'type to search · enter plays · esc quits' \
    --bind "change:reload:sleep 0.25; \"$self\" --rows {q} 2>/dev/null || true")" || exit 0
else
  rows_out="$(rows "$query")" || {
    printf '%s\n' "${rows_out%%$'\t'*}"
    exit 1
  }
  [[ -n "$rows_out" ]] || exit 0
  i=0
  while IFS= read -r line; do
    i=$((i + 1))
    printf '%2d) %s\n' "$i" "${line%%$'\t'*}"
  done <<<"$rows_out"
  printf 'play which? '
  read -r n || exit 0
  [[ "$n" =~ ^[0-9]+$ ]] || exit 0
  pick="$(sed -n "${n}p" <<<"$rows_out")"
fi
[[ -n "$pick" ]] || exit 0
play "$pick"
```

- [ ] **Step 5: Run, lint, commit**

```bash
git commit -m "feat(spotify): nekoshell-spotify-search, a search bar that plays what you pick"
```

---

### Task 2: The subcommand, the alias, the docs

**Files:**

- Modify: `plugins/spotify/cmd/spotify.sh` (usage + `search) exec "$PLUGIN_DIR/bin/nekoshell-spotify-search" "$@" ;;`), `plugins/spotify/README.md`, `docs/plugins/spotify.md`, `CHANGELOG.md`
- Create: `plugins/spotify/plugin.zsh` (`alias sps='nekoshell spotify search'`)

- [ ] **Step 1:** Make the last test of Task 1 pass; docs: the "Using it" table gains `nekoshell spotify search [QUERY]` / `sps`, a paragraph on the bar (type, Enter plays on the active device, which means the player window or the desktop app must be running; the upstream parse error and what to do).

- [ ] **Step 2:** `bats tests/plugins/spotify.bats tests/core/cli.bats && scripts/lint.sh`; commit `docs(spotify): the search bar in the readme and the manual`.

---

### Task 3: On this Mac and the PR

- [ ] With the player running (`nekoshell music` in another window): `nekoshell spotify search "hello"` from a kitty window, pick a track, hear it. Try the empty-query bar and type. Try `daft punk` and see the error row rather than a hang.
- [ ] `gh pr create` on `feat/spotify-search`.
