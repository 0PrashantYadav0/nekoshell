#!/usr/bin/env bash
# terminal: detect, list, switch and configure terminals
usage_terminal() {
  cat <<'EOF'
usage: nekoshell terminal detect | list | use ID | apply | capabilities
EOF
}
cmd_terminal() {
  local action="${1:-list}"
  [[ $# -gt 0 ]] && shift
  case "$action" in
    detect)
      local t
      if t="$(terminal_detect_env)"; then echo "$t"; else
        echo "unknown"
        return 1
      fi
      ;;
    list) _terminal_cmd_list ;;
    use)
      local id="${1:-}"
      [[ -n "$id" ]] || {
        usage_terminal
        return 2
      }
      terminal_load "$id" || return 1
      config_set terminal "$id"
      terminal_apply "$(theme_current)"
      ;;
    apply)
      local cur
      cur="$(terminal_current 2>/dev/null || true)"
      [[ -n "$cur" ]] || {
        log_fail "no terminal configured"
        return 1
      }
      terminal_load "$cur" || return 1
      terminal_apply "$(theme_current)"
      ;;
    capabilities)
      local cur
      cur="$(terminal_current 2>/dev/null || true)"
      [[ -n "$cur" ]] || {
        log_fail "no terminal configured"
        return 1
      }
      terminal_load "$cur" || return 1
      terminal_capabilities
      ;;
    -h | --help | help) usage_terminal ;;
    *)
      usage_terminal
      return 2
      ;;
  esac
}
_terminal_cmd_list() {
  local id cur inst mark
  cur="$(terminal_current 2>/dev/null || true)"
  for id in $(terminal_all); do
    if (terminal_load "$id" && terminal_installed) >/dev/null 2>&1; then inst="installed"; else inst="not installed"; fi
    mark=""
    [[ "$id" == "$cur" ]] && mark=" *"
    printf '%-14s %s%s\n' "$id" "$inst" "$mark"
  done
  return 0
}
