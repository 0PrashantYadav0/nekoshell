#!/usr/bin/env bash
# uninstall: remove plugins, unlink the zshrc, restore your files from backup
# Keeps zsh/local.zsh, the backup dir, the configs plugins rendered or copied
# into place, and the pokemon-colorscripts checkout; the closing lines say so.
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
      # A plugin hook that fails must not strand the uninstall half done, with
      # the zshrc still linked and the backup unrestored: warn and carry on.
      plugin_remove "${enabled[$i]}" "$PURGE" || log_warn "${enabled[$i]}: could not be removed cleanly; carrying on"
    done
  fi

  unlink_tree "$NEKOSHELL_ROOT/core/zsh" "$HOME"
  backup_restore_all

  # starship.toml is only ours to remove if we rendered it; a user's own
  # config, or one left by something else, is never touched.
  if [[ -f "$HOME/.config/starship.toml" ]] && grep -qF 'nekoshell Starship config' "$HOME/.config/starship.toml" 2>/dev/null; then
    run rm -f "$HOME/.config/starship.toml"
  fi
  # The terminal's own config, while the toml still says which terminal it is.
  local term=""
  term="$(terminal_current 2>/dev/null || true)"
  if [[ -n "$term" ]] && terminal_load "$term" 2>/dev/null; then
    terminal_remove || log_warn "terminal $term: could not remove its config"
  fi
  run rm -f "$NEKOSHELL_CONFIG/theme.zsh" "$NEKOSHELL_CONFIG/antidote.txt" "$NEKOSHELL_TOML"

  log_ok "nekoshell removed."
  log_info "Left in place: ~/.config/nekoshell/zsh/local.zsh, ~/.config/fastfetch/config.jsonc, ~/.config/tmux/nekoshell-theme.conf, ~/.config/btop/btop.conf, ~/.local/share/pokemon-colorscripts (and its ~/.local/bin symlink), anything a plugin copied, and the backup at $NEKOSHELL_BACKUP_ROOT"
}
