#!/usr/bin/env bash
# uninstall: remove plugins, unlink the zshrc, restore your files from backup
# Keeps zsh/local.zsh, the backup dir, and anything files/copy put in place.
usage_uninstall() { cat <<'EOF'
usage: nekoshell uninstall [--yes] [--purge]
EOF
}

cmd_uninstall() {
  local YES=0 PURGE=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes) YES=1; shift ;;
      --purge) PURGE=purge; shift ;;
      -h|--help|help) usage_uninstall; return 0 ;;
      *) usage_uninstall; return 2 ;;
    esac
  done

  if [[ "$YES" != 1 ]]; then
    confirm "Remove nekoshell links and restore your previous files?" || { log_warn "aborted"; return 1; }
  fi

  # Reverse order: plugin_add enables a dependency before its dependent, so
  # removing in reverse always removes a dependent before what it needs.
  local -a enabled=()
  local p
  while IFS= read -r p; do [[ -n "$p" ]] && enabled+=("$p"); done < <(plugin_enabled_all)
  if [[ ${#enabled[@]} -gt 0 ]]; then
    local i
    for (( i = ${#enabled[@]} - 1; i >= 0; i-- )); do
      plugin_remove "${enabled[$i]}" "$PURGE" || return 1
    done
  fi

  unlink_tree "$NEKOSHELL_ROOT/core/zsh" "$HOME"
  backup_restore_all

  # starship.toml is only ours to remove if we rendered it; a user's own
  # config, or one left by something else, is never touched.
  if [[ -f "$HOME/.config/starship.toml" ]] && grep -qF 'nekoshell Starship config' "$HOME/.config/starship.toml" 2>/dev/null; then
    run rm -f "$HOME/.config/starship.toml"
  fi
  run rm -f "$NEKOSHELL_CONFIG/theme.zsh" "$NEKOSHELL_CONFIG/antidote.txt" "$NEKOSHELL_TOML"

  log_ok "nekoshell removed. Left in place: ~/.config/nekoshell/zsh/local.zsh, files plugins copied, and the backup at $NEKOSHELL_BACKUP_ROOT"
}
