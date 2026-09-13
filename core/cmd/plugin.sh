#!/usr/bin/env bash
# plugin: list, info, add, remove plugins
usage_plugin() {
  cat <<'EOF'
usage: nekoshell plugin list | info NAME | add NAME... | remove [--purge] NAME...
EOF
}
cmd_plugin() {
  local action="${1:-list}"
  [[ $# -gt 0 ]] && shift
  case "$action" in
    list) _plugin_cmd_list ;;
    info)
      [[ -n "${1:-}" ]] || {
        usage_plugin
        return 2
      }
      plugin_exists "$1" || {
        log_fail "no plugin named $1"
        return 1
      }
      cat "$(plugin_dir "$1")/plugin.toml"
      echo
      [[ -r "$(plugin_dir "$1")/README.md" ]] && cat "$(plugin_dir "$1")/README.md"
      return 0
      ;;
    add)
      [[ $# -gt 0 ]] || {
        usage_plugin
        return 2
      }
      backup_begin
      local n
      for n in "$@"; do plugin_add "$n" || return 1; done
      ;;
    remove)
      [[ $# -gt 0 ]] || {
        usage_plugin
        return 2
      }
      local purge="" n
      [[ "${1:-}" == "--purge" ]] && {
        purge=purge
        shift
      }
      for n in "$@"; do plugin_remove "$n" "$purge" || return 1; done
      ;;
    -h | --help | help) usage_plugin ;;
    *)
      usage_plugin
      return 2
      ;;
  esac
}
_plugin_cmd_list() {
  local p state term
  term="$(terminal_current || true)"
  for p in $(plugin_all); do
    if plugin_enabled "$p"; then
      state=enabled
    elif [[ -n "$term" ]] && ! plugin_supports_terminal "$p" "$term"; then
      state=unavailable
    else state=available; fi
    printf '%-14s %-12s %s\n' "$p" "$state" "$(plugin_meta "$p" summary)"
  done
  return 0
}
