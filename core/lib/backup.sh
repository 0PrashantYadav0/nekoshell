#!/usr/bin/env bash
# Backups of files the installer replaces. Requires core/lib/log.sh and core/lib/paths.sh.
# Source this file; do not execute it.

# backup_root_inside_checkout: true when the backup root sits inside the
# checkout, where re-cloning or `git clean` would take the user's originals
# with it. Nothing may be backed up until that is fixed.
backup_root_inside_checkout() {
  [[ "$NEKOSHELL_BACKUP_ROOT" == "$NEKOSHELL_ROOT"/* ]]
}

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

# backup_link_target_lexical ABS_SYMLINK: the symlink's target as an absolute
# path, resolved textually against the link's own directory. backup_link_target
# needs the target's directory to still exist; this one does not, which is the
# shape a v0.1 stow link has once the tree it pointed into was deleted. Purely
# textual, so it never follows a further symlink: use it only as a fallback for
# a link backup_link_target could not resolve.
backup_link_target_lexical() {
  local src="$1" target out seg
  target="$(readlink "$src" 2>/dev/null)" || return 1
  [[ -n "$target" ]] || return 1
  if [[ "$target" == /* ]]; then
    printf '%s\n' "$target"
    return 0
  fi
  out="$(dirname "$src")"
  local IFS='/'
  for seg in $target; do
    case "$seg" in
      '' | .) ;;
      ..)
        out="${out%/*}"
        [[ -n "$out" ]] || out="/"
        ;;
      *) out="${out%/}/$seg" ;;
    esac
  done
  printf '%s\n' "$out"
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
    printf '%s\n' "$rel" >>"$NEKOSHELL_BACKUP_DIR/manifest.txt"
  fi
}

# _backup_restore_one DIR: move every manifest entry of one backup set back
# into $HOME, then retire its manifest so a second uninstall skips the set.
_backup_restore_one() {
  local dir="$1" rel
  [[ -r "$dir/manifest.txt" ]] || return 0
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    # An entry already restored (or never saved) must not clobber what is in
    # $HOME now: only remove the destination when there is a source to move.
    # That guard is also what lets an older set be applied after a newer one:
    # whatever the newer set already put back is left where it is.
    [[ -e "$dir/$rel" || -L "$dir/$rel" ]] || continue
    run rm -rf "$HOME/$rel"
    run mkdir -p "$HOME/$(dirname "$rel")"
    run mv "$dir/$rel" "$HOME/$rel"
  done <"$dir/manifest.txt"
  log_ok "restored $(wc -l <"$dir/manifest.txt" | tr -d ' ') paths from $dir"
  run mv "$dir/manifest.txt" "$dir/manifest.restored"
}

# backup_restore_all: every backup set that still has a manifest, newest first.
# Each `nekoshell plugin add` begins a set of its own, so by the time uninstall
# runs there is usually more than one of them and only the oldest holds the
# files the first install replaced. Newest first, with _backup_restore_one's
# "only move when there is a source" guard, means an older set never overwrites
# a newer original, while the oldest set - the true original - is still applied
# to everything the newer sets did not cover.
backup_restore_all() {
  local dir dirs=() i
  # Backup dirs are UTC timestamps, so the glob is already oldest-first.
  for dir in "$NEKOSHELL_BACKUP_ROOT"/*/; do
    [[ -d "$dir" && -r "${dir%/}/manifest.txt" ]] || continue
    dirs+=("${dir%/}")
  done
  if [[ ${#dirs[@]} -eq 0 ]]; then
    log_warn "no backup to restore"
    return 0
  fi
  for ((i = ${#dirs[@]} - 1; i >= 0; i--)); do
    _backup_restore_one "${dirs[$i]}"
  done
}
