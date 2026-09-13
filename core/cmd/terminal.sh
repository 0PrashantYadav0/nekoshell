#!/usr/bin/env bash
# terminal: detect, list, configure and theme the terminals you use
usage_terminal() {
  cat <<'EOF'
usage: nekoshell terminal detect | list | use ID...|all|installed | remove ID | apply | background PATH|none [OPACITY] | capabilities

  detect        the terminal this shell runs in
  list          every adapter, whether its app is installed, and * for the configured ones
  use           configure one or more terminals (font, colours, panel) and remember them
  remove        take nekoshell's config back out of one terminal and forget it
  apply         re-render every configured terminal in the current flavour
  background    a background image (or none) for every configured terminal that can draw one
  capabilities  what the terminal this shell runs in can do
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
      [[ $# -gt 0 ]] || {
        usage_terminal
        return 2
      }
      local -a ids=()
      local id expanded
      # Expanded into a variable first: a process substitution's status never
      # reaches the loop reading it, and an unknown id has to fail here.
      expanded="$(terminal_expand_ids "$@")" || return 1
      while IFS= read -r id; do [[ -n "$id" ]] && ids+=("$id"); done <<<"$expanded"
      [[ ${#ids[@]} -gt 0 ]] || {
        log_fail "no terminal matched: $*"
        return 1
      }
      terminal_configure "${ids[@]}"
      ;;
    remove)
      local id="${1:-}"
      [[ -n "$id" ]] || {
        usage_terminal
        return 2
      }
      terminal_load "$id" || return 1
      terminal_remove || log_warn "terminal $id: could not remove its config"
      config_list_remove terminals "$id"
      if [[ "$(config_get terminal 2>/dev/null || true)" == "$id" ]]; then
        config_set terminal "$(terminal_configured_all | head -n 1)"
      fi
      log_ok "terminal $id removed"
      ;;
    apply)
      local -a ids=()
      local id flavor rc=0
      while IFS= read -r id; do [[ -n "$id" ]] && ids+=("$id"); done < <(terminal_configured_all)
      [[ ${#ids[@]} -gt 0 ]] || {
        log_fail "no terminal configured; run: nekoshell terminal use <id>"
        return 1
      }
      flavor="$(theme_current)"
      for id in "${ids[@]}"; do
        terminal_load "$id" || {
          rc=1
          continue
        }
        terminal_apply "$flavor" || log_warn "terminal $id: theme not applied"
      done
      return "$rc"
      ;;
    background)
      # Every configured terminal that can draw one, so the picture follows
      # the theme onto each of them; one that cannot is skipped, not failed.
      local -a ids=()
      local id caps any=0 rc=0
      [[ $# -gt 0 ]] || {
        usage_terminal
        return 2
      }
      while IFS= read -r id; do [[ -n "$id" ]] && ids+=("$id"); done < <(terminal_configured_all)
      [[ ${#ids[@]} -gt 0 ]] || {
        log_fail "no terminal configured; run: nekoshell terminal use <id>"
        return 1
      }
      for id in "${ids[@]}"; do
        terminal_load "$id" || {
          rc=1
          continue
        }
        caps=" $(terminal_capabilities) "
        case "$caps" in *" background "*) ;; *)
          log_info "$id cannot draw a background image; skipped"
          continue
          ;;
        esac
        any=1
        terminal_background "$@" || rc=1
      done
      [[ "$any" == 1 ]] || log_warn "none of the configured terminals draws a background image"
      return "$rc"
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
  local id inst mark
  for id in $(terminal_all); do
    if (terminal_load "$id" && terminal_installed) >/dev/null 2>&1; then inst="installed"; else inst="not installed"; fi
    mark=""
    terminal_is_configured "$id" && mark=" *"
    printf '%-14s %s%s\n' "$id" "$inst" "$mark"
  done
  return 0
}
