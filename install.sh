#!/usr/bin/env bash
# nekoshell installer. Idempotent. Re-run any time.
set -euo pipefail

NEKOSHELL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export NEKOSHELL_ROOT
# shellcheck source=lib/log.sh
source "$NEKOSHELL_ROOT/lib/log.sh"
# shellcheck source=lib/paths.sh
source "$NEKOSHELL_ROOT/lib/paths.sh"
# shellcheck source=lib/backup.sh
source "$NEKOSHELL_ROOT/lib/backup.sh"
# shellcheck source=lib/iterm.sh
source "$NEKOSHELL_ROOT/lib/iterm.sh"
# shellcheck source=lib/theme.sh
source "$NEKOSHELL_ROOT/lib/theme.sh"
# shellcheck source=lib/zsh_migrate.sh
source "$NEKOSHELL_ROOT/lib/zsh_migrate.sh"

CHECK=0; YES=0; SKIP_BREW=0; SKIP_SPOTIFY=0; ONLY_PREFS=0
for arg in "$@"; do
  case "$arg" in
    --check) CHECK=1 ;;
    --dry-run) NEKOSHELL_DRY_RUN=1; export NEKOSHELL_DRY_RUN ;;
    --yes|-y) YES=1 ;;
    --skip-brew) SKIP_BREW=1 ;;
    --skip-spotify) SKIP_SPOTIFY=1 ;;
    --iterm-prefs) ONLY_PREFS=1 ;;
    -h|--help)
      sed -n '2p' "$0"
      echo "usage: install.sh [--check] [--dry-run] [--yes] [--skip-brew] [--skip-spotify] [--iterm-prefs]"
      exit 0 ;;
    *) log_fail "unknown flag: $arg"; exit 2 ;;
  esac
done

TOTAL=12
ZSHRC_LINK="$NEKOSHELL_ROOT/stow/zsh/.zshrc"
GIT_INCLUDE="$NEKOSHELL_CONFIG/git/delta.gitconfig"
POKEMON_DIR="$HOME/.local/share/pokemon-colorscripts"
POKEMON_BIN="$HOME/.local/bin/pokemon-colorscripts"
TPM_DIR="$HOME/.config/tmux/plugins/tpm"
NVIM_DIR="$HOME/.config/nvim"
TMUX_DIR="$HOME/.config/tmux"
ITERM_SHELL_INTEGRATION="$HOME/.iterm2_shell_integration.zsh"

# RENDERED_PATHS: files the installer renders from templates/ rather than stows,
# so stowed_paths cannot see them. The first install still replaces whatever is
# already there, so they are backed up by hand. See backup_rendered_paths.
RENDERED_PATHS=".config/starship.toml .config/fastfetch/config.jsonc .iterm2_shell_integration.zsh"

# stowed_paths: every path stow will claim in $HOME, one per line, relative to
# $HOME. Read from the packages themselves so the backup can never drift from
# what stow --no-folding actually links (leaf files only: --no-folding creates
# real directories, so a directory in $HOME is never replaced).
stowed_paths() {
  local pkg
  for pkg in zsh config; do
    ( cd "$NEKOSHELL_ROOT/stow/$pkg" && find . -type f -print | sed 's|^\./||' )
  done
}

# backup_rendered_paths: back up the rendered files, but only on the install that
# first replaces them. After that they are nekoshell's own output, and moving
# them aside every run would pile up a backup directory per install. The theme
# state file is written by that first install and marks every one after it.
backup_rendered_paths() {
  local rel
  [[ -e "$NEKOSHELL_CONFIG/theme" ]] && return 0
  for rel in $RENDERED_PATHS; do
    backup_path "$rel"
  done
}

# zshrc_linked: true when ~/.zshrc is the symlink this checkout installs.
zshrc_linked() {
  [[ -L "$HOME/.zshrc" && "$HOME/.zshrc" -ef "$ZSHRC_LINK" ]]
}

confirm() {
  [[ "$YES" == 1 ]] && return 0
  printf '%s [y/N] ' "$1"
  read -r reply
  [[ "$reply" == y* || "$reply" == Y* ]]
}

preflight() {
  [[ -n "${NEKOSHELL_SKIP_PREFLIGHT:-}" ]] && return 0
  [[ "$(uname -s)" == "Darwin" ]] || { log_fail "nekoshell v0.1 supports macOS only"; exit 1; }
  command -v brew >/dev/null 2>&1 || {
    log_fail "Homebrew is required. Install it first:"
    # shellcheck disable=SC2016  # the command line is printed verbatim, not evaluated
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
  }
  command -v zsh >/dev/null 2>&1 || { log_fail "zsh not found"; exit 1; }
  [[ -d /Applications/iTerm.app || -d "$HOME/Applications/iTerm.app" ]] || { log_fail "iTerm2 not found. Install it first: brew install --cask iterm2"; exit 1; }
  command -v stow >/dev/null 2>&1 || [[ "$SKIP_BREW" == 0 ]] || { log_fail "stow is missing and --skip-brew was given"; exit 1; }
}

# --check: list what would change. Exit 0 with "nothing to do" when installed.
check_only() {
  local todo=0
  zshrc_linked || { log_info "would stow ~/.zshrc"; todo=1; }
  [[ "$(cat "$NEKOSHELL_CONFIG/root" 2>/dev/null)" == "$NEKOSHELL_ROOT" ]] || { log_info "would record root"; todo=1; }
  [[ -f "$ITERM_DYNAMIC_DIR/nekoshell.json" ]] || { log_info "would write iTerm2 profiles"; todo=1; }
  [[ -f "$NEKOSHELL_CONFIG/theme.zsh" ]] || { log_info "would render the theme"; todo=1; }
  [[ -L "$POKEMON_BIN" ]] || { log_info "would install pokemon-colorscripts"; todo=1; }
  [[ -f "$ITERM_SHELL_INTEGRATION" ]] || { log_info "would download iTerm2 shell integration"; todo=1; }
  if [[ -e "$NVIM_DIR/init.lua" || -e "$NVIM_DIR/init.vim" ]]; then
    log_info "Neovim config already at $NVIM_DIR; the template would be left in templates/nvim"
  else
    log_info "would copy templates/nvim to $NVIM_DIR"; todo=1
  fi
  if [[ -e "$HOME/.tmux.conf" || -e "$TMUX_DIR/tmux.conf" ]]; then
    log_info "tmux config already in place; the template would be left in templates/tmux"
  else
    log_info "would copy templates/tmux/tmux.conf to $TMUX_DIR"; todo=1
  fi
  [[ -d "$TPM_DIR" ]] || { log_info "would clone the tmux plugin manager"; todo=1; }
  if iterm_prefs_pending; then log_info "iTerm2 global prefs pending (run: ./install.sh --iterm-prefs with iTerm2 closed)"; fi
  if [[ "$todo" == 0 ]]; then log_ok "nothing to do"; fi
  exit 0
}

apply_prefs_step() {
  if iterm_is_running; then
    log_warn "iTerm2 is running; global prefs are pending. Quit iTerm2, then run from Terminal.app:"
    echo "  $NEKOSHELL_ROOT/install.sh --iterm-prefs"
    return 0
  fi
  iterm_apply_prefs
  log_ok "iTerm2 global prefs applied"
}

# dep_sha NAME: the commit deps.lock pins for NAME, or a non-zero status when
# the line is missing or is not a full hash. bash 3.2 keeps the pattern in a
# variable: an unquoted literal on the right of =~ is the only portable shape.
dep_sha() {
  local sha re='^[0-9a-f]{40}$'
  sha="$(sed -n "s/^$1=//p" "$NEKOSHELL_ROOT/deps.lock" | head -1)"
  [[ "$sha" =~ $re ]] || return 1
  printf '%s\n' "$sha"
}

# check_deps_lock: read every pin before anything moves. An empty line would
# otherwise reach `git checkout ""` in a step that runs after the backup, with
# the user's files already out of place and an ERR trap to explain it.
check_deps_lock() {
  local name
  for name in pokemon-colorscripts tpm; do
    dep_sha "$name" >/dev/null || {
      log_fail "deps.lock has no valid commit for $name; this checkout is incomplete"
      exit 1
    }
  done
}

install_pokemon_colorscripts() {
  local sha
  sha="$(dep_sha pokemon-colorscripts)"
  if [[ ! -d "$POKEMON_DIR" ]]; then
    run git clone --quiet https://gitlab.com/phoneybadger/pokemon-colorscripts.git "$POKEMON_DIR"
  else
    # An older clone may not have the pinned commit yet.
    run git -C "$POKEMON_DIR" fetch --quiet
  fi
  run git -C "$POKEMON_DIR" checkout --quiet "$sha"
  run chmod +x "$POKEMON_DIR/pokemon-colorscripts.py"
  run mkdir -p "$HOME/.local/bin"
  run ln -sfn "$POKEMON_DIR/pokemon-colorscripts.py" "$POKEMON_BIN"
}

# install_tpm: the tmux plugin manager, cloned at the commit deps.lock pins.
#
# The path matters. TPM picks its own plugin directory from where the config
# lives: with a ~/.config/tmux/tmux.conf it uses ~/.config/tmux/plugins/, not
# ~/.tmux/plugins/. A clone in the other place is simply never read, and TPM
# clones itself again, unpinned, the first time it runs. tmux.conf also sets
# TMUX_PLUGIN_MANAGER_PATH to the same directory, so the two cannot drift.
#
# TPM itself is all the installer fetches; the plugins tmux.conf lists arrive
# when the user presses C-a I, because TPM is an interactive tool and running
# its installer headless here would leave a half-populated plugin directory
# nobody asked for. tmux.conf guards its `run` line, so a machine without this
# clone still has a config that parses.
install_tpm() {
  local sha
  sha="$(dep_sha tpm)"
  if [[ ! -d "$TPM_DIR" ]]; then
    run mkdir -p "$(dirname "$TPM_DIR")"
    run git clone --quiet https://github.com/tmux-plugins/tpm.git "$TPM_DIR"
  else
    # An older clone may not have the pinned commit yet.
    run git -C "$TPM_DIR" fetch --quiet
  fi
  run git -C "$TPM_DIR" checkout --quiet "$sha"
}

# install_user_configs: the configs that are the user's to edit, copied once and
# then never touched again. A symlink back into the checkout would turn every
# edit of theirs into a change to the repo, so these are real files.
#
# The Neovim and tmux configs are all or nothing, and nekoshell always loses the
# tie. Copying our files in one at a time beside someone else's would build a
# config neither of us wrote, and there is no version of that which is the
# user's own. The tests for "is one already here" are wider than the files we
# write, because both tools have more than one name for their entry point:
#
#   nvim  init.vim is shadowed by init.lua rather than merged with it, so a
#         vimscript config would go quiet without a single file being replaced.
#   tmux  3.x reads ~/.config/tmux/tmux.conf in preference to ~/.tmux.conf, so
#         writing ours would take over a config that is still in use.
#
# Nothing here is ever backed up, because nothing here is ever replaced.
install_user_configs() {
  if [[ ! -e "$NEKOSHELL_CONFIG/greet.conf" ]]; then
    run cp "$NEKOSHELL_ROOT/templates/greet.conf" "$NEKOSHELL_CONFIG/greet.conf"
  fi
  if [[ -e "$NVIM_DIR/init.lua" || -e "$NVIM_DIR/init.vim" ]]; then
    log_warn "existing Neovim config found at ~/.config/nvim; leaving it alone (nekoshell's is in templates/nvim)"
  else
    run mkdir -p "$NVIM_DIR"
    run cp -R "$NEKOSHELL_ROOT/templates/nvim/." "$NVIM_DIR/"
  fi
  if [[ -e "$HOME/.tmux.conf" || -e "$TMUX_DIR/tmux.conf" ]]; then
    log_warn "existing tmux config found; leaving it alone (nekoshell's is in templates/tmux/tmux.conf)"
  else
    run mkdir -p "$TMUX_DIR"
    run cp "$NEKOSHELL_ROOT/templates/tmux/tmux.conf" "$TMUX_DIR/tmux.conf"
  fi
}

# install_shell_integration: iTerm2's own zsh hooks. They report the working
# directory and the last command's status, which is what the status bar's
# working directory and git components read. Downloaded rather than vendored
# because it is iTerm2's file and has to match the running iTerm2. Not tied to
# --skip-brew: it is not a Homebrew package. A failed download is not a failed
# install either, because everything else about the rig works without it, so
# this warns and carries on rather than tripping the ERR trap.
install_shell_integration() {
  run curl -fsSL https://iterm2.com/shell_integration/zsh -o "$ITERM_SHELL_INTEGRATION" \
    || log_warn "iTerm2 shell integration download failed; the status bar's working directory and git components will stay blank"
}

# The include path is its own marker: it appears once, so a re-run is a no-op.
add_gitconfig_include() {
  local gc="$HOME/.gitconfig"
  if [[ -r "$gc" ]] && grep -qF "$GIT_INCLUDE" "$gc"; then return 0; fi
  if [[ "$NEKOSHELL_DRY_RUN" == "1" ]]; then log_info "would add the delta include to ~/.gitconfig"; return 0; fi
  printf '\n# added by install.sh\n[include]\n\tpath = %s\n' "$GIT_INCLUDE" >> "$gc"
  log_ok "delta include added to ~/.gitconfig"
}

main() {
  # --check answers from the filesystem alone, so it must not need Homebrew.
  [[ "$CHECK" == 1 ]] && check_only
  preflight
  # iTerm2 rewrites its own plist when it quits, so anything written now would
  # be thrown away. Refuse rather than pretend the prefs were applied.
  if [[ "$ONLY_PREFS" == 1 ]]; then
    if iterm_is_running; then log_fail "iTerm2 is running; quit it and run this again"; exit 1; fi
    iterm_apply_prefs; log_ok "iTerm2 global prefs applied"; exit 0
  fi

  log_step 1 $TOTAL "Preflight"
  log_ok "macOS, Homebrew, zsh present. Checkout: $NEKOSHELL_ROOT"
  check_deps_lock
  confirm "Install nekoshell into $HOME?" || { log_warn "aborted"; exit 1; }

  log_step 2 $TOTAL "Homebrew packages"
  if [[ "$SKIP_BREW" == 1 ]]; then
    log_warn "skipped (--skip-brew)"
  else
    run brew bundle --file "$NEKOSHELL_ROOT/Brewfile" --no-upgrade
  fi

  log_step 3 $TOTAL "Back up files nekoshell replaces"
  if backup_root_inside_checkout; then
    log_fail "backups would land inside the checkout at $NEKOSHELL_BACKUP_ROOT; move the checkout out of $NEKOSHELL_ROOT and run this again"
    exit 1
  fi
  backup_begin
  local rel old_zshrc="" zshrc_target="" FLAVOR=""
  # A symlinked .zshrc (a dotfiles repo, usually) holds the aliases at the other
  # end of the link. Resolve it now: backup_path is about to move the link.
  if [[ -L "$HOME/.zshrc" ]]; then
    zshrc_target="$(backup_link_target "$HOME/.zshrc" || true)"
    if [[ -n "$zshrc_target" && -f "$zshrc_target" && "$zshrc_target" != "$NEKOSHELL_ROOT"/* ]]; then
      old_zshrc="$zshrc_target"
    else
      zshrc_target=""
    fi
  elif [[ -f "$HOME/.zshrc" ]]; then
    old_zshrc="$NEKOSHELL_BACKUP_DIR/.zshrc"
  fi
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    backup_path "$rel"
  done < <(stowed_paths)
  backup_rendered_paths
  if [[ -d "$NEKOSHELL_BACKUP_DIR" ]]; then log_ok "backup at $NEKOSHELL_BACKUP_DIR"; else log_ok "nothing to back up"; fi

  # Your files are saved from here on, so say where they are if a later step
  # dies. -E so a failure inside one of the helper functions reaches the trap.
  set -E
  trap 'log_fail "install failed after backup; restore with: $NEKOSHELL_ROOT/uninstall.sh --yes"' ERR

  log_step 4 $TOTAL "Theme, your configs and your aliases"
  run mkdir -p "$NEKOSHELL_CONFIG/zsh"
  install_user_configs
  # starship.toml and the fastfetch config are rendered once and then yours, the
  # same deal as greet.conf; theme.zsh is nekoshell's and is always rewritten.
  # Switching flavour later is `nekoshell-theme <flavour>`, which rewrites all of
  # them. An earlier choice wins over the default, so a re-install keeps it.
  FLAVOR="$(theme_current)"
  theme_write_files "$FLAVOR" keep
  log_ok "theme: $FLAVOR"
  if [[ -n "$zshrc_target" ]]; then
    log_info "your ~/.zshrc was a symlink to $zshrc_target; migrating from there"
  fi
  if [[ -n "$old_zshrc" && "$NEKOSHELL_DRY_RUN" != "1" ]]; then
    log_ok "$(zsh_migrate_aliases "$old_zshrc" "$NEKOSHELL_CONFIG/zsh/local.zsh") lines copied to ~/.config/nekoshell/zsh/local.zsh"
  else
    log_info "no previous .zshrc to migrate"
  fi

  log_step 5 $TOTAL "Link configs with stow"
  run stow --no-folding --dir "$NEKOSHELL_ROOT/stow" --target "$HOME" --restow zsh config
  # bat reads themes from its own cache, so the tmTheme files stow just linked
  # into ~/.config/bat/themes stay invisible until the cache is rebuilt.
  theme_build_bat_cache

  log_step 6 $TOTAL "Record checkout location"
  run mkdir -p "$NEKOSHELL_CONFIG" "$NEKOSHELL_CACHE"
  if [[ "$NEKOSHELL_DRY_RUN" != "1" ]]; then printf '%s\n' "$NEKOSHELL_ROOT" > "$NEKOSHELL_CONFIG/root"; fi

  log_step 7 $TOTAL "pokemon-colorscripts"
  install_pokemon_colorscripts

  log_step 8 $TOTAL "tmux plugin manager"
  install_tpm

  log_step 9 $TOTAL "git delta include"
  add_gitconfig_include

  log_step 10 $TOTAL "iTerm2 shell integration"
  install_shell_integration

  log_step 11 $TOTAL "iTerm2 profiles"
  iterm_write_profiles "$FLAVOR"
  log_ok "profiles: nekoshell, nekoshell panel (hotkey ⌥M)"

  log_step 12 $TOTAL "iTerm2 global preferences"
  apply_prefs_step

  trap - ERR
  echo
  log_ok "installed. Human steps left:"
  echo "  1. Quit and reopen iTerm2 (pick the 'nekoshell' profile if it is not the default)."
  [[ "$SKIP_SPOTIFY" == 1 ]] || echo "  2. Run: spotify_player authenticate   (opens a browser; needs Spotify Premium)"
  echo "  3. Press ⌥M anywhere for the Spotify panel."
  echo "  4. Start tmux and press C-a I once to install its plugins. Run nekoshell-doctor to verify."
}

main
