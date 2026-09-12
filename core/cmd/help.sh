#!/usr/bin/env bash
# help: list core and plugin commands
usage_help() { cat <<'EOF'
usage: nekoshell help
EOF
}
cmd_help() {
  echo "usage: nekoshell <command> [args]"
  echo
  echo "Commands:"
  local f name desc
  for f in "$NEKOSHELL_ROOT"/core/cmd/*.sh; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f" .sh)"
    desc="$(sed -n '2p' "$f")"
    desc="${desc#\# }"
    printf '  %-12s %s\n' "$name" "$desc"
  done
  echo
  echo "Plugin commands:"
  local d pname cmdf state any=0
  for d in "$NEKOSHELL_PLUGINS_DIR"/*/; do
    [[ -d "${d}cmd" ]] || continue
    pname="$(basename "$d")"
    if plugin_enabled "$pname"; then state="enabled"; else state="not enabled"; fi
    for cmdf in "${d}cmd"/*.sh; do
      [[ -f "$cmdf" ]] || continue
      any=1
      printf '  %-12s (plugin %s, %s)\n' "$(basename "$cmdf" .sh)" "$pname" "$state"
    done
  done
  [[ "$any" == 1 ]] || echo "  (none)"
  return 0
}
