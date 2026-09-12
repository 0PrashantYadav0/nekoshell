#!/usr/bin/env bash
# Mirror a folder of files into $HOME as symlinks (like stow) or copies that are
# made once and then belong to the user. Needs paths.sh, log.sh, backup.sh.
# Source this file; do not execute it.

# _link_files SRC: every regular file under SRC, sorted, absolute.
_link_files() { [[ -d "$1" ]] && find "$1" -type f | sort; return 0; }

# link_tree SRC DEST: DEST/<relative> -> SRC/<relative> for every file. A real
# file in the way is backed up first; a foreign symlink is replaced. DEST must
# be under $HOME: backup_path takes a path relative to $HOME, not an absolute
# one, so the target is rebased onto $HOME before it is handed over.
link_tree() {
  local src="$1" dest="$2" f rel target
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    rel="${f#"$src"/}"; target="$dest/$rel"
    mkdir -p "$(dirname "$target")"
    if [[ -L "$target" ]]; then
      [[ "$(readlink "$target")" == "$f" ]] && continue
      rm -f "$target"
    elif [[ -e "$target" ]]; then
      backup_path "${target#"$HOME"/}"
    fi
    ln -s "$f" "$target"
  done < <(_link_files "$src")
}

# unlink_tree SRC DEST: remove DEST symlinks that point into SRC. Nothing else.
unlink_tree() {
  local src="$1" dest="$2" f rel target
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    rel="${f#"$src"/}"; target="$dest/$rel"
    [[ -L "$target" && "$(readlink "$target")" == "$f" ]] && rm -f "$target"
  done < <(_link_files "$src")
}

# copy_once SRC DEST: copy files that are not there yet. Existing ones are the
# user's and are reported as kept.
copy_once() {
  local src="$1" dest="$2" f rel target
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    rel="${f#"$src"/}"; target="$dest/$rel"
    if [[ -e "$target" || -L "$target" ]]; then log_info "kept $rel (yours)"; continue; fi
    mkdir -p "$(dirname "$target")"
    cp "$f" "$target"
  done < <(_link_files "$src")
}
