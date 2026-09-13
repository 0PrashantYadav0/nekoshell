#!/usr/bin/env bash
# modern-cli uninstall: take the delta include back out of ~/.gitconfig. Only
# the region this plugin wrote is removed; everything else in the file is the
# user's and is left exactly as it was. The bat config and themes are symlinks,
# which the core unlinks on its own.

MC_GITCONFIG="$HOME/.gitconfig"
MC_BEGIN="# nekoshell:modern-cli begin"

if [[ -f "$MC_GITCONFIG" ]] && grep -qF "$MC_BEGIN" "$MC_GITCONFIG"; then
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would remove the delta include from ~/.gitconfig"
  else
    mc_tmp="$MC_GITCONFIG.nekoshell.tmp"
    awk '
      /^# nekoshell:modern-cli begin$/ { skip = 1 }
      skip != 1 { print }
      /^# nekoshell:modern-cli end$/   { skip = 0 }
    ' "$MC_GITCONFIG" > "$mc_tmp" && mv "$mc_tmp" "$MC_GITCONFIG"
    log_ok "delta include removed from ~/.gitconfig"
  fi
fi

true
