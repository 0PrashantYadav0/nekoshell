#!/usr/bin/env bash
# art: manage the greeting's art pack
usage_art() {
  cat <<'USAGE'
usage: nekoshell art <command>

  list          files in the art pack
  add <image>   copy a PNG/JPG into the art pack
  sample        copy the shipped sample images into the art pack

The pack lives in ~/.config/nekoshell/art. Transparent PNGs look best; the
size is set by IMAGE_WIDTH and IMAGE_HEIGHT in ~/.config/nekoshell/greet.conf.
USAGE
}

cmd_art() {
  local art_dir="$NEKOSHELL_CONFIG/art"
  case "${1:-}" in
    list)
      mkdir -p "$art_dir"
      find "$art_dir" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) -exec basename {} \; | sort
      ;;
    add)
      [[ -f "${2:-}" ]] || {
        log_fail "no such file: ${2:-}"
        return 1
      }
      mkdir -p "$art_dir"
      cp "$2" "$art_dir/"
      log_ok "added $(basename "$2")"
      ;;
    sample)
      # The samples come from the plugin that is running, not from anything
      # recorded, so they are the ones this checkout ships.
      mkdir -p "$art_dir"
      cp "$PLUGIN_DIR"/art/*.png "$art_dir/"
      log_ok "copied $(find "$PLUGIN_DIR/art" -maxdepth 1 -name '*.png' -type f | wc -l | tr -d ' ') sample images"
      ;;
    -h | --help | help)
      usage_art
      return 0
      ;;
    *)
      usage_art >&2
      return 2
      ;;
  esac
}
