#!/usr/bin/env bash
# Mirror a folder of files into $HOME as symlinks (like stow) or copies that are
# made once and then belong to the user. Needs paths.sh, log.sh, backup.sh.
# Source this file; do not execute it.

# _link_files SRC: every regular file under SRC, sorted, absolute.
_link_files() {
  [[ -d "$1" ]] && find "$1" -type f | sort
  return 0
}

# link_tree SRC DEST: DEST/<relative> -> SRC/<relative> for every file. A real
# file in the way is backed up first; a foreign symlink is replaced. DEST must
# be under $HOME: backup_path takes a path relative to $HOME, not an absolute
# one, so the target is rebased onto $HOME before it is handed over. Under
# NEKOSHELL_DRY_RUN=1, nothing is touched (not even a backup); one "would
# link" line is printed per file that is not already linked correctly.
link_tree() {
  local src="$1" dest="$2" f rel target
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    rel="${f#"$src"/}"
    target="$dest/$rel"
    if [[ -L "$target" && "$(readlink "$target")" == "$f" ]]; then continue; fi
    if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
      log_info "would link $rel"
      continue
    fi
    mkdir -p "$(dirname "$target")"
    if [[ -L "$target" ]]; then
      rm -f "$target"
    elif [[ -e "$target" ]]; then
      backup_path "${target#"$HOME"/}"
    fi
    ln -s "$f" "$target"
  done < <(_link_files "$src")
}

# unlink_tree SRC DEST: remove DEST symlinks that point into SRC. Nothing else.
# Under NEKOSHELL_DRY_RUN=1, one "would unlink" line is printed per link that
# would be removed and nothing is touched.
unlink_tree() {
  local src="$1" dest="$2" f rel target
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    rel="${f#"$src"/}"
    target="$dest/$rel"
    [[ -L "$target" && "$(readlink "$target")" == "$f" ]] || continue
    if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
      log_info "would unlink $rel"
      continue
    fi
    rm -f "$target"
  done < <(_link_files "$src")
}

# copy_once SRC DEST: copy files that are not there yet. Existing ones are the
# user's and are reported as kept. Under NEKOSHELL_DRY_RUN=1, one "would copy"
# line is printed per missing file and nothing is touched.
copy_once() {
  local src="$1" dest="$2" f rel target
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    rel="${f#"$src"/}"
    target="$dest/$rel"
    if [[ -e "$target" || -L "$target" ]]; then
      log_info "kept $rel (yours)"
      continue
    fi
    if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
      log_info "would copy $rel"
      continue
    fi
    mkdir -p "$(dirname "$target")"
    cp "$f" "$target"
  done < <(_link_files "$src")
}
