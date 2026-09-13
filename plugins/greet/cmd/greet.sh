#!/usr/bin/env bash
# greet: print the terminal greeting now
usage_greet() {
  cat <<'USAGE'
usage: nekoshell greet [--image|--text]

  --image   use the art pack, if this terminal can draw images
  --text    use the Pokémon sprite, whatever the terminal can do

With neither, the greeting rolls for it: POKEMON_SHARE in
~/.config/nekoshell/greet.conf is the percentage that goes to the Pokémon.
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
