#!/usr/bin/env bash
# Copy a user's plain aliases and exports out of their old .zshrc.
# Source this file; do not execute it.

# zsh_migrate_aliases OLD_ZSHRC DEST: write matching lines to DEST unless DEST exists.
# Prints the number of lines written.
zsh_migrate_aliases() {
  local old="$1" dest="$2" count=0 line
  if [[ -e "$dest" || ! -r "$old" ]]; then
    echo 0
    return 0
  fi
  {
    echo "# Migrated from your previous .zshrc by nekoshell on $(date -u +%Y-%m-%dT%H:%M:%SZ)."
    echo "# Edit freely; nekoshell never overwrites this file."
    while IFS= read -r line; do
      case "$line" in
        alias\ *|export\ *)
          case "$line" in
            *oh-my-zsh*|*ZSH=*|*p10k*|*POWERLEVEL*) continue ;;
          esac
          printf '%s\n' "$line"
          count=$((count + 1))
          ;;
      esac
    done < "$old"
  } > "$dest"
  echo "$count"
}
