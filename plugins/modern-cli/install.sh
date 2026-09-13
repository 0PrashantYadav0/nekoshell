#!/usr/bin/env bash
# modern-cli install: point git's pager at delta.
#
# ~/.gitconfig is the user's file, so nothing here rewrites it: the include is
# appended once, inside a marked region uninstall.sh can take back out again.
# Idempotency is judged on the include path rather than on the marker, so a
# checkout upgraded from v0.1 (whose include carries `# added by install.sh`
# instead) does not end up with the same include twice.

MC_GITCONFIG="$HOME/.gitconfig"
MC_INCLUDE="$HOME/.config/nekoshell/git/delta.gitconfig"
MC_BEGIN="# nekoshell:modern-cli begin"
MC_END="# nekoshell:modern-cli end"

if [[ -r "$MC_GITCONFIG" ]] && grep -qF "$MC_INCLUDE" "$MC_GITCONFIG"; then
  : # already there
elif [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
  log_info "would add the delta include to ~/.gitconfig"
else
  # A file that does not end in a newline would otherwise take the marker onto
  # the end of its last line.
  if [[ -s "$MC_GITCONFIG" ]] && [[ -n "$(tail -c 1 "$MC_GITCONFIG")" ]]; then
    printf '\n' >> "$MC_GITCONFIG"
  fi
  printf '%s\n[include]\n\tpath = %s\n%s\n' "$MC_BEGIN" "$MC_INCLUDE" "$MC_END" >> "$MC_GITCONFIG"
  log_ok "delta include added to ~/.gitconfig"
fi

true
