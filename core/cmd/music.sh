#!/usr/bin/env bash
# music: open the music player, in a terminal panel or right here
usage_music() { cat <<'EOF'
usage: nekoshell music [PLAYER] [--here]

PLAYER defaults to the `music_player` setting in nekoshell.toml, which itself
defaults to "auto": the first enabled plugin tagged `media`, in the order the
plugins are enabled.
EOF
}

# _music_auto_player: the first enabled plugin whose plugin.toml tags contain
# `media`. Status 1 and no output when no enabled plugin is a media plugin.
_music_auto_player() {
  local p t
  for p in $(plugin_enabled_all); do
    for t in $(plugin_meta_list "$p" tags); do
      [[ "$t" == "media" ]] && { printf '%s\n' "$p"; return 0; }
    done
  done
  return 1
}

# _music_binary PLAYER: the player's own launcher. A media plugin ships it as
# plugins/<player>/bin/nekoshell-<player>; the PATH fallback is for a player
# installed some other way (and for the shim the zshrc puts on PATH).
_music_binary() {
  local bin
  bin="$(plugin_dir "$1")/bin/nekoshell-$1"
  [[ -x "$bin" ]] && { printf '%s\n' "$bin"; return 0; }
  command -v "nekoshell-$1" 2>/dev/null && return 0
  return 1
}

cmd_music() {
  local here=0 player="" bin term
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --here) here=1; shift ;;
      -h|--help|help) usage_music; return 0 ;;
      -*) usage_music; return 2 ;;
      *) player="$1"; shift ;;
    esac
  done

  [[ -n "$player" ]] || player="$(config_get music_player 2>/dev/null || true)"
  [[ -n "$player" ]] || player="auto"
  if [[ "$player" == "auto" ]]; then
    player="$(_music_auto_player || true)"
    [[ -n "$player" ]] || {
      log_fail "no media plugin enabled; try: nekoshell plugin add spotify"
      return 1
    }
  fi

  bin="$(_music_binary "$player" || true)"
  [[ -n "$bin" ]] || { log_fail "$player has no player binary (nekoshell-$player)"; return 1; }

  if [[ "$here" -eq 1 ]]; then "$bin"; return $?; fi

  # No terminal configured or no adapter for it: there is no panel to open, so
  # the player runs here rather than not at all.
  term="$(terminal_current 2>/dev/null || true)"
  if [[ -n "$term" ]] && terminal_load "$term" 2>/dev/null; then
    terminal_panel "$bin"
  else
    "$bin"
  fi
}
