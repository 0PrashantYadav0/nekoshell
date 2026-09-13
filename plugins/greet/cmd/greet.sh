#!/usr/bin/env bash
# greet: print the terminal greeting now
usage_greet() {
  cat <<'USAGE'
usage: nekoshell greet [--image|--text|--art NAME]

  --image      use the art pack, if this terminal can draw images
  --text       use a sprite from an enabled art provider, whatever the terminal
  --art NAME   use that provider's sprite (pokemon, anime, ...)

With none of them, the greeting rolls for it: SPRITE_SHARE in
~/.config/nekoshell/greet.conf is the percentage that goes to a sprite, and
ART says which providers draw.
USAGE
}

cmd_greet() {
  local mode="auto"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --image)
        mode="image"
        shift
        ;;
      --text)
        mode="text"
        shift
        ;;
      --art)
        [[ -n "${2:-}" ]] || {
          usage_greet >&2
          return 2
        }
        if ! plugin_enabled "$2" || [[ ! -x "$(plugin_dir "$2")/greet-art" ]]; then
          log_fail "$2 is not an enabled art provider (nekoshell plugin list)"
          return 1
        fi
        export NEKOSHELL_GREET_ART="$2"
        mode="text"
        shift 2
        ;;
      -h | --help | help)
        usage_greet
        return 0
        ;;
      *)
        usage_greet >&2
        return 2
        ;;
    esac
  done
  # exec, not a call: the greeting is the last thing this process has to do,
  # and the mode reaches it as the environment variable it reads.
  export NEKOSHELL_GREET_MODE="$mode"
  exec "$PLUGIN_DIR/bin/nekoshell-greet"
}
