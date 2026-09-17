#!/usr/bin/env bash
# greet: print the terminal greeting now
usage_greet() {
  cat <<'USAGE'
usage: nekoshell greet [--image|--text|--art NAME]

  --image      use the art pack, if this terminal can draw images
  --text       use a sprite from an enabled art provider, whatever the terminal
  --art NAME   use that provider's sprite or picture (pokemon, anime, ...)

With none of them, the greeting rolls for it: SPRITE_SHARE in
~/.config/nekoshell/greet.conf is the percentage that goes to a sprite, and
ART says which providers draw.
USAGE
}

# _greet_term_draws_images: does the current terminal's adapter list images
# among its capabilities? Loading the adapter here is safe: the greeting is
# exec'd next, and reads the adapter afresh.
_greet_term_draws_images() {
  local term
  term="$(terminal_current 2>/dev/null || true)"
  [[ -n "$term" ]] || return 1
  terminal_load "$term" >/dev/null 2>&1 || return 1
  case " $(terminal_capabilities 2>/dev/null || true) " in
    *" images "*) return 0 ;;
  esac
  return 1
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
        if ! plugin_enabled "$2" || {
          [[ ! -x "$(plugin_dir "$2")/greet-art" ]] && [[ ! -x "$(plugin_dir "$2")/greet-image" ]]
        }; then
          log_fail "$2 is not an enabled art provider (nekoshell plugin list)"
          return 1
        fi
        # A provider that only draws pictures has nothing for a terminal that
        # cannot show them; the greeting would print the stats alone, and
        # someone who asked for it by name deserves to hear why.
        if [[ ! -x "$(plugin_dir "$2")/greet-art" ]] && ! _greet_term_draws_images; then
          log_fail "$2 draws pictures, which the $(terminal_current 2>/dev/null || echo current) terminal cannot show"
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
