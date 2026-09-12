#!/usr/bin/env bash
# theme: switch or inspect the colour theme
usage_theme() { cat <<'EOF'
usage: nekoshell theme list | current | auto | --resolve | FLAVOUR
EOF
}
cmd_theme() {
  local action="${1:-current}"
  case "$action" in
    list) theme_flavors ;;
    current) theme_current ;;
    --resolve)
      local s r
      s="$(theme_setting)"
      if [[ "$s" == "auto" ]]; then
        r="$(theme_resolve)"
        if [[ "$r" != "$(config_get theme_resolved 2>/dev/null || true)" ]]; then
          theme_apply "$r"
        fi
      fi
      return 0
      ;;
    auto)
      config_set theme auto
      theme_apply "$(theme_resolve)"
      ;;
    -h|--help|help) usage_theme ;;
    *)
      theme_is_flavor "$action" || { log_fail "unknown flavour: $action"; return 1; }
      config_set theme "$action"
      theme_apply "$action"
      ;;
  esac
}
