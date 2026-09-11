#!/usr/bin/env bash
# Backups of files the installer replaces. Requires lib/log.sh and lib/paths.sh.
# Source this file; do not execute it.

# backup_begin: name a timestamped backup dir. The directory itself is created
# lazily by the first backup_path that actually moves something, so a run with
# nothing to back up (and any --dry-run) leaves no empty directory behind.
backup_begin() {
  NEKOSHELL_BACKUP_DIR="$NEKOSHELL_BACKUP_ROOT/$(date -u +%Y%m%dT%H%M%SZ)"
  export NEKOSHELL_BACKUP_DIR
}

# backup_link_target ABS_SYMLINK: print the symlink's target as an absolute path.
# stow writes relative links, so a plain readlink cannot be compared to a root.
backup_link_target() {
  local src="$1" target dir
  target="$(readlink "$src")" || return 1
  if [[ "$target" == /* ]]; then
    printf '%s\n' "$target"
    return 0
  fi
  dir="$(cd "$(dirname "$src")" 2>/dev/null && cd "$(dirname "$target")" 2>/dev/null && pwd -P)" || return 1
  [[ -n "$dir" ]] || return 1
  printf '%s/%s\n' "${dir%/}" "$(basename "$target")"
}

# backup_path REL: move $HOME/REL (file, dir or foreign symlink) into the backup dir.
# Symlinks that already point into NEKOSHELL_ROOT are left alone (idempotent re-runs).
backup_path() {
  local rel="$1" src="$HOME/$1" target
  [[ -e "$src" || -L "$src" ]] || return 0
  if [[ -L "$src" ]]; then
    target="$(backup_link_target "$src" || true)"
    if [[ -n "$target" && "$target" == "$NEKOSHELL_ROOT"/* ]]; then
      return 0
    fi
  fi
  run mkdir -p "$NEKOSHELL_BACKUP_DIR/$(dirname "$rel")"
  run mv "$src" "$NEKOSHELL_BACKUP_DIR/$rel"
  if [[ "$NEKOSHELL_DRY_RUN" != "1" ]]; then
    printf '%s\n' "$rel" >> "$NEKOSHELL_BACKUP_DIR/manifest.txt"
  fi
}

# backup_restore_latest: move every manifest entry of the newest backup back into $HOME.
backup_restore_latest() {
  local latest="" rel dir
  # Backup dirs are UTC timestamps, so the last glob match is the newest.
  for dir in "$NEKOSHELL_BACKUP_ROOT"/*/; do
    [[ -d "$dir" ]] && latest="${dir%/}"
  done
  [[ -n "$latest" && -r "$latest/manifest.txt" ]] || { log_warn "no backup to restore"; return 0; }
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    # An entry already restored (or never saved) must not clobber what is in
    # $HOME now: only remove the destination when there is a source to move.
    [[ -e "$latest/$rel" || -L "$latest/$rel" ]] || continue
    run rm -rf "$HOME/$rel"
    run mkdir -p "$HOME/$(dirname "$rel")"
    run mv "$latest/$rel" "$HOME/$rel"
  done < "$latest/manifest.txt"
  log_ok "restored $(wc -l < "$latest/manifest.txt" | tr -d ' ') paths from $latest"
  # Retire the manifest so a second uninstall finds nothing to restore.
  run mv "$latest/manifest.txt" "$latest/manifest.restored"
}
