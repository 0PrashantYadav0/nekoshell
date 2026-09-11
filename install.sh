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

TOTAL=10
ZSHRC_LINK="$NEKOSHELL_ROOT/stow/zsh/.zshrc"
GIT_INCLUDE="$NEKOSHELL_CONFIG/git/delta.gitconfig"
POKEMON_DIR="$HOME/.local/share/pokemon-colorscripts"
POKEMON_BIN="$HOME/.local/bin/pokemon-colorscripts"

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
  command -v stow >/dev/null 2>&1 || [[ "$SKIP_BREW" == 0 ]] || { log_fail "stow is missing and --skip-brew was given"; exit 1; }
}

# --check: list what would change. Exit 0 with "nothing to do" when installed.
check_only() {
  local todo=0
  zshrc_linked || { log_info "would stow ~/.zshrc"; todo=1; }
  [[ "$(cat "$NEKOSHELL_CONFIG/root" 2>/dev/null)" == "$NEKOSHELL_ROOT" ]] || { log_info "would record root"; todo=1; }
  [[ -f "$ITERM_DYNAMIC_DIR/nekoshell.json" ]] || { log_info "would write iTerm2 profiles"; todo=1; }
  [[ -L "$POKEMON_BIN" ]] || { log_info "would install pokemon-colorscripts"; todo=1; }
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

install_pokemon_colorscripts() {
  local sha
  sha="$(sed -n 's/^pokemon-colorscripts=//p' "$NEKOSHELL_ROOT/deps.lock")"
  if [[ ! -d "$POKEMON_DIR" ]]; then
    run git clone --quiet https://gitlab.com/phoneybadger/pokemon-colorscripts.git "$POKEMON_DIR"
  fi
  run git -C "$POKEMON_DIR" checkout --quiet "$sha"
  run chmod +x "$POKEMON_DIR/pokemon-colorscripts.py"
  run mkdir -p "$HOME/.local/bin"
  run ln -sfn "$POKEMON_DIR/pokemon-colorscripts.py" "$POKEMON_BIN"
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
  [[ "$ONLY_PREFS" == 1 ]] && { iterm_apply_prefs; log_ok "iTerm2 global prefs applied"; exit 0; }

  log_step 1 $TOTAL "Preflight"
  log_ok "macOS, Homebrew, zsh present. Checkout: $NEKOSHELL_ROOT"
  confirm "Install nekoshell into $HOME?" || { log_warn "aborted"; exit 1; }

  log_step 2 $TOTAL "Homebrew packages"
  if [[ "$SKIP_BREW" == 1 ]]; then
    log_warn "skipped (--skip-brew)"
  else
    run brew bundle --file "$NEKOSHELL_ROOT/Brewfile" --no-upgrade
  fi

  log_step 3 $TOTAL "Back up files nekoshell replaces"
  backup_begin
  local rel old_zshrc=""
  [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]] && old_zshrc="$NEKOSHELL_BACKUP_DIR/.zshrc"
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    backup_path "$rel"
  done < <(stowed_paths)
  if [[ -d "$NEKOSHELL_BACKUP_DIR" ]]; then log_ok "backup at $NEKOSHELL_BACKUP_DIR"; else log_ok "nothing to back up"; fi

  # Your files are saved from here on, so say where they are if a later step
  # dies. -E so a failure inside one of the helper functions reaches the trap.
  set -E
  trap 'log_fail "install failed after backup; restore with: $NEKOSHELL_ROOT/uninstall.sh --yes"' ERR

  log_step 4 $TOTAL "Migrate your aliases"
  run mkdir -p "$NEKOSHELL_CONFIG/zsh"
  if [[ -n "$old_zshrc" && "$NEKOSHELL_DRY_RUN" != "1" ]]; then
    log_ok "$(zsh_migrate_aliases "$old_zshrc" "$NEKOSHELL_CONFIG/zsh/local.zsh") lines copied to ~/.config/nekoshell/zsh/local.zsh"
  else
    log_info "no previous .zshrc to migrate"
  fi

  log_step 5 $TOTAL "Link configs with stow"
  run stow --no-folding --dir "$NEKOSHELL_ROOT/stow" --target "$HOME" --restow zsh config

  log_step 6 $TOTAL "Record checkout location"
  run mkdir -p "$NEKOSHELL_CONFIG" "$NEKOSHELL_CACHE"
  if [[ "$NEKOSHELL_DRY_RUN" != "1" ]]; then printf '%s\n' "$NEKOSHELL_ROOT" > "$NEKOSHELL_CONFIG/root"; fi

  log_step 7 $TOTAL "pokemon-colorscripts"
  install_pokemon_colorscripts

  log_step 8 $TOTAL "git delta include"
  add_gitconfig_include

  log_step 9 $TOTAL "iTerm2 profiles"
  iterm_write_profiles
  log_ok "profiles: nekoshell, nekoshell panel (hotkey ⌥M)"

  log_step 10 $TOTAL "iTerm2 global preferences"
  apply_prefs_step

  trap - ERR
  echo
  log_ok "installed. Human steps left:"
  echo "  1. Quit and reopen iTerm2 (pick the 'nekoshell' profile if it is not the default)."
  [[ "$SKIP_SPOTIFY" == 1 ]] || echo "  2. Run: spotify_player authenticate   (opens a browser; needs Spotify Premium)"
  echo "  3. Press ⌥M anywhere for the Spotify panel. Run nekoshell-doctor to verify."
}

main
