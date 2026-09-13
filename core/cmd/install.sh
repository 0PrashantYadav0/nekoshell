#!/usr/bin/env bash
# install: link the zshrc, pick a terminal and profile, apply the theme, enable plugins
# Idempotent: a second run changes nothing and backs up nothing new.
# --check implies --dry-run and mutates nothing.
usage_install() { cat <<'EOF'
usage: nekoshell install [--profile P] [--with a,b] [--without c] [--yes] [--check] [--dry-run] [--terminal ID]
EOF
}

# _install_in_list NEEDLE HAY...: true when NEEDLE is one of HAY.
_install_in_list() {
  local needle="$1" hay; shift
  for hay in "$@"; do [[ "$hay" == "$needle" ]] && return 0; done
  return 1
}

# _install_detect_terminal: --terminal wins; then the quick env-only check
# (real terminal apps on a real Mac); then each adapter's own terminal_detect
# (what the fixture "fake" terminal uses, via FAKE_TERM, so this path is
# exercised without a real terminal app). The adapter probe runs in a
# subshell so a non-matching (or matching) adapter's functions never leak
# into the caller's shell; whoever ends up using the chosen id calls
# terminal_load again for real (theme_apply does, via terminal_current).
# Prints the id or nothing.
_install_detect_terminal() {
  local id t
  if t="$(terminal_detect_env 2>/dev/null)"; then
    printf '%s\n' "$t"
    return 0
  fi
  for id in $(terminal_all); do
    if ( terminal_load "$id" 2>/dev/null && terminal_detect 2>/dev/null ); then
      printf '%s\n' "$id"
      return 0
    fi
  done
  return 1
}

# _install_pick_from_list PROMPT ITEM...: an interactive `select`; invalid
# input reprompts (select's own behaviour), and a blank line or a closed
# stdin gives up with nothing printed. Prints the chosen item, or nothing.
_install_pick_from_list() {
  local prompt="$1" choice=""; shift
  PS3="$prompt "
  select choice in "$@"; do
    [[ -n "$choice" ]] && break
    [[ -z "${REPLY:-}" ]] && break
  done
  [[ -n "$choice" ]] && printf '%s\n' "$choice"
  return 0
}

# _install_pick_plugins: a second select loop, toggling names from plugin_all
# on and off, ending on "done" (or EOF). Prints the chosen names, one per line.
_install_pick_plugins() {
  local -a all=() chosen=()
  local name idx found
  while IFS= read -r name; do [[ -n "$name" ]] && all+=("$name"); done < <(plugin_all)
  [[ ${#all[@]} -eq 0 ]] && return 0
  PS3="toggle a plugin, or 'done': "
  while true; do
    select name in "${all[@]}" "done"; do
      break
    done
    [[ -z "${REPLY:-}" ]] && break
    [[ "$name" == "done" ]] && break
    [[ -z "$name" ]] && continue
    found=0
    if [[ ${#chosen[@]} -gt 0 ]]; then
      for idx in "${!chosen[@]}"; do
        if [[ "${chosen[$idx]}" == "$name" ]]; then unset 'chosen[idx]'; found=1; break; fi
      done
    fi
    [[ "$found" == 0 ]] && chosen+=("$name")
  done
  if [[ ${#chosen[@]} -gt 0 ]]; then printf '%s\n' "${chosen[@]}"; fi
  return 0
}

# _install_after_notes NAME: the lines of NAME's README.md under "## After
# install", if it has that section.
_install_after_notes() {
  local readme
  readme="$(plugin_dir "$1")/README.md"
  [[ -r "$readme" ]] || return 0
  awk '/^## After install/{flag=1; next} /^## /{flag=0} flag' "$readme"
  return 0
}

cmd_install() {
  local PROFILE="" WITH="" WITHOUT="" YES=0 CHECK=0 TERMINAL_FLAG=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile) PROFILE="${2:-}"; shift 2 ;;
      --with) WITH="${2:-}"; shift 2 ;;
      --without) WITHOUT="${2:-}"; shift 2 ;;
      --yes) YES=1; shift ;;
      --check) CHECK=1; shift ;;
      --dry-run) NEKOSHELL_DRY_RUN=1; export NEKOSHELL_DRY_RUN; shift ;;
      --terminal) TERMINAL_FLAG="${2:-}"; shift 2 ;;
      -h|--help|help) usage_install; return 0 ;;
      *) usage_install; return 2 ;;
    esac
  done
  if [[ "$CHECK" == 1 ]]; then NEKOSHELL_DRY_RUN=1; export NEKOSHELL_DRY_RUN; fi

  local TOTAL=7

  # --- Preflight (unnumbered; skippable). ---------------------------------
  if [[ -z "${NEKOSHELL_SKIP_PREFLIGHT:-}" ]]; then
    [[ "$(uname -s)" == "Darwin" ]] || { log_fail "nekoshell supports macOS only"; return 1; }
    if ! command -v brew >/dev/null 2>&1; then
      log_fail "Homebrew is required. Install it first:"
      # shellcheck disable=SC2016
      echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
      return 1
    fi
    command -v zsh >/dev/null 2>&1 || { log_fail "zsh not found"; return 1; }
    command -v git >/dev/null 2>&1 || { log_fail "git not found"; return 1; }
  fi

  # --- 1: Terminal. --------------------------------------------------------
  log_step 1 "$TOTAL" "Terminal"
  local term=""
  if [[ -n "$TERMINAL_FLAG" ]]; then
    terminal_load "$TERMINAL_FLAG" || return 1
    term="$TERMINAL_FLAG"
  else
    term="$(_install_detect_terminal || true)"
  fi
  if [[ -z "$term" && -t 0 ]]; then
    local -a installed=()
    while IFS= read -r id; do [[ -n "$id" ]] && installed+=("$id"); done < <(terminal_installed_all)
    if [[ ${#installed[@]} -gt 0 ]]; then
      term="$(_install_pick_from_list "terminal?" "${installed[@]}")"
    fi
  fi
  if [[ -z "$term" ]]; then
    log_warn "no terminal detected; run nekoshell terminal use <id> later"
  else
    log_ok "terminal: $term"
  fi

  # --- 2: Profile. -----------------------------------------------------------
  log_step 2 "$TOTAL" "Profile"
  local profiles_dir="${NEKOSHELL_PROFILES_DIR:-$NEKOSHELL_ROOT/profiles}"
  local chosen_profile="$PROFILE"
  if [[ -z "$chosen_profile" ]]; then
    if [[ -t 0 && "$YES" != 1 ]]; then
      chosen_profile="$(_install_pick_from_list "profile?" minimal dev full pick)"
      [[ -z "$chosen_profile" ]] && chosen_profile="minimal"
    else
      log_info "no --profile given and no terminal to ask on: using minimal"
      chosen_profile="minimal"
    fi
  fi
  local -a profile_plugins=()
  if [[ "$chosen_profile" == "pick" ]]; then
    while IFS= read -r p; do [[ -n "$p" ]] && profile_plugins+=("$p"); done < <(_install_pick_plugins)
  else
    local profile_file="$profiles_dir/$chosen_profile.txt"
    [[ -f "$profile_file" ]] || { log_fail "no profile named $chosen_profile"; return 1; }
    while IFS= read -r p; do [[ -n "$p" ]] && profile_plugins+=("$p"); done < "$profile_file"
  fi
  local -a with_arr=() without_arr=()
  [[ -n "$WITH" ]] && IFS=',' read -r -a with_arr <<< "$WITH"
  [[ -n "$WITHOUT" ]] && IFS=',' read -r -a without_arr <<< "$WITHOUT"
  if [[ ${#with_arr[@]} -gt 0 ]]; then
    local w
    for w in "${with_arr[@]}"; do [[ -n "$w" ]] && profile_plugins+=("$w"); done
  fi
  local -a final_plugins=()
  if [[ ${#profile_plugins[@]} -gt 0 ]]; then
    local p
    for p in "${profile_plugins[@]}"; do
      if [[ ${#without_arr[@]} -gt 0 ]] && _install_in_list "$p" "${without_arr[@]}"; then continue; fi
      if [[ ${#final_plugins[@]} -gt 0 ]] && _install_in_list "$p" "${final_plugins[@]}"; then continue; fi
      final_plugins+=("$p")
    done
  fi
  if [[ ${#final_plugins[@]} -gt 0 ]]; then
    local pchk
    for pchk in "${final_plugins[@]}"; do
      plugin_exists "$pchk" || { log_fail "no plugin named $pchk"; return 1; }
    done
  fi
  log_ok "profile: $chosen_profile (${final_plugins[*]:-none})"

  # --- 3: Confirm. -----------------------------------------------------------
  log_step 3 "$TOTAL" "Confirm"
  if [[ "$CHECK" == 1 || "$YES" == 1 ]]; then
    log_info "skipped (--yes or --check)"
  else
    confirm "Install nekoshell into $HOME?" || { log_warn "aborted"; return 1; }
  fi

  # --- 4: Backup + core. -------------------------------------------------
  log_step 4 "$TOTAL" "Backup + core"
  if backup_root_inside_checkout; then
    log_fail "backups would land inside the checkout at $NEKOSHELL_BACKUP_ROOT; move the checkout out of $NEKOSHELL_ROOT and run this again"
    return 1
  fi
  backup_begin
  local old_theme=""
  if [[ -e "$NEKOSHELL_CONFIG/theme" ]]; then
    old_theme="$(cat "$NEKOSHELL_CONFIG/theme" 2>/dev/null || true)"
    run rm -f "$NEKOSHELL_CONFIG/theme"
  fi
  [[ -e "$NEKOSHELL_CONFIG/root" ]] && run rm -f "$NEKOSHELL_CONFIG/root"
  if [[ -L "$HOME/.zshrc" ]]; then
    local zshrc_target
    zshrc_target="$(backup_link_target "$HOME/.zshrc" 2>/dev/null || true)"
    if [[ -n "$zshrc_target" && "$zshrc_target" == "$NEKOSHELL_ROOT"/* ]]; then
      # Already nekoshell's: the old stow-era file was never the user's (its
      # aliases lived in the stowed .zshrc itself, not something to migrate),
      # so it is simply dropped. A link already at the current core/zsh path
      # is left for link_tree's own idempotent check.
      if [[ "$zshrc_target" == "$NEKOSHELL_ROOT/stow"* ]]; then
        run rm -f "$HOME/.zshrc"
      fi
    else
      # A foreign symlink (a dotfiles repo, usually): the aliases live at the
      # other end of the link. Migrate from there when it resolves to a real
      # file, then back up the symlink itself — backup_path moves rather
      # than dereferences a symlink not pointing into the checkout — so
      # `nekoshell uninstall` can restore it exactly as it was.
      if [[ -n "$zshrc_target" && -f "$zshrc_target" ]]; then
        if [[ "$NEKOSHELL_DRY_RUN" == "1" ]]; then
          log_info "would migrate aliases from ~/.zshrc (-> $zshrc_target)"
        else
          mkdir -p "$NEKOSHELL_CONFIG/zsh"
          local migrated
          migrated="$(zsh_migrate_aliases "$zshrc_target" "$NEKOSHELL_CONFIG/zsh/local.zsh")"
          if [[ "$migrated" =~ ^[0-9]+$ ]] && [[ "$migrated" -gt 0 ]]; then
            log_ok "$migrated lines migrated to ~/.config/nekoshell/zsh/local.zsh"
          fi
        fi
      fi
      backup_path .zshrc
    fi
  elif [[ -f "$HOME/.zshrc" ]]; then
    if [[ "$NEKOSHELL_DRY_RUN" == "1" ]]; then
      log_info "would migrate aliases from ~/.zshrc"
    else
      local migrated
      mkdir -p "$NEKOSHELL_CONFIG/zsh"
      migrated="$(zsh_migrate_aliases "$HOME/.zshrc" "$NEKOSHELL_CONFIG/zsh/local.zsh")"
      if [[ "$migrated" =~ ^[0-9]+$ ]] && [[ "$migrated" -gt 0 ]]; then
        log_ok "$migrated lines migrated to ~/.config/nekoshell/zsh/local.zsh"
      fi
    fi
  fi
  link_tree "$NEKOSHELL_ROOT/core/zsh" "$HOME"
  if [[ "$NEKOSHELL_DRY_RUN" == "1" ]]; then
    log_info "would write nekoshell.toml"
  else
    config_set root "$NEKOSHELL_ROOT"
    [[ -n "$term" ]] && config_set terminal "$term"
    local theme_val
    theme_val="$(config_get theme 2>/dev/null || true)"
    if [[ -z "$theme_val" ]]; then
      if [[ -n "$old_theme" ]]; then theme_val="$old_theme"; else theme_val="$NEKOSHELL_DEFAULT_FLAVOR"; fi
    fi
    config_set theme "$theme_val"
    config_set profile "$chosen_profile"
    # A brand-new toml has no "plugins" key at all until plugin_add writes
    # one; an empty profile would otherwise leave the file without one.
    # Never touched when the key already exists, so an existing list from a
    # previous install is never reset by re-running install.
    config_has plugins || toml_set_list "$NEKOSHELL_TOML" plugins
  fi

  # --- 5: Theme. ---------------------------------------------------------
  log_step 5 "$TOTAL" "Theme"
  if [[ "$NEKOSHELL_DRY_RUN" == "1" ]]; then
    log_info "would apply theme $(theme_resolve)"
  else
    theme_apply "$(theme_resolve)"
  fi

  # --- 6: Plugins. ---------------------------------------------------------
  log_step 6 "$TOTAL" "Plugins"
  if [[ "$NEKOSHELL_DRY_RUN" == "1" ]]; then
    log_info "would enable: ${final_plugins[*]:-(none)}"
  elif [[ ${#final_plugins[@]} -gt 0 ]]; then
    local name
    for name in "${final_plugins[@]}"; do
      plugin_add "$name" || { log_fail "stopped at $name; re-run nekoshell install to continue"; return 1; }
    done
  fi

  # --- 7: Doctor + human steps. --------------------------------------------
  log_step 7 "$TOTAL" "Doctor and next steps"
  if [[ "$NEKOSHELL_DRY_RUN" != "1" ]]; then
    # shellcheck source=core/cmd/doctor.sh
    source "$NEKOSHELL_ROOT/core/cmd/doctor.sh"
    # shellcheck disable=SC2119 # deliberately no args: the full doctor block
    cmd_doctor || true
    local any=0 notes enabled_name
    for enabled_name in $(plugin_enabled_all); do
      notes="$(_install_after_notes "$enabled_name")"
      if [[ -n "$notes" ]]; then
        log_head "$enabled_name: after install"
        printf '%s\n' "$notes"
        any=1
      fi
    done
    [[ "$any" == 0 ]] && log_info "no extra human steps"
    log_ok "installed"
  else
    log_info "dry run: nothing was changed"
  fi
}
