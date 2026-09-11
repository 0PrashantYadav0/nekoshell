#!/usr/bin/env bash
# Undo install.sh: unstow, restore the newest backup, remove the iTerm2 profiles.
set -euo pipefail
NEKOSHELL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export NEKOSHELL_ROOT
# shellcheck source=lib/log.sh
source "$NEKOSHELL_ROOT/lib/log.sh"
# shellcheck source=lib/paths.sh
source "$NEKOSHELL_ROOT/lib/paths.sh"
# shellcheck source=lib/backup.sh
source "$NEKOSHELL_ROOT/lib/backup.sh"

YES=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y) YES=1 ;;
    --dry-run) NEKOSHELL_DRY_RUN=1; export NEKOSHELL_DRY_RUN ;;
    -h|--help)
      sed -n '2p' "$0"
      echo "usage: uninstall.sh [--yes] [--dry-run]"
      exit 0 ;;
    *) log_fail "unknown flag: $arg"; exit 2 ;;
  esac
done
if [[ "$YES" != 1 ]]; then
  printf 'Remove nekoshell links and restore your previous files? [y/N] '
  read -r reply; [[ "$reply" == y* || "$reply" == Y* ]] || exit 1
fi

run stow --no-folding --dir "$NEKOSHELL_ROOT/stow" --target "$HOME" --delete zsh config
backup_restore_latest
run rm -f "$ITERM_DYNAMIC_DIR/nekoshell.json" "$NEKOSHELL_CONFIG/root"
log_ok "nekoshell removed. Homebrew packages were left in place; to remove them:"
echo "  brew bundle cleanup --file $NEKOSHELL_ROOT/Brewfile --force"
echo "  (and: defaults delete com.googlecode.iterm2 'Default Bookmark Guid')"
