#!/usr/bin/env bash
# modern-cli doctor: one row per binary, plus bat's theme cache.

for mc_tool in eza bat fd rg zoxide delta; do
  if command -v "$mc_tool" >/dev/null 2>&1; then
    report ok "tool: $mc_tool" "$(command -v "$mc_tool")"
  else
    report fail "tool: $mc_tool" "missing (nekoshell plugin add modern-cli)"
  fi
done

# The themes only reach bat through its cache, so a flavour that is not in
# `bat --list-themes` means the cache is stale, not that the file is missing.
# The listing is captured rather than piped into grep: hooks run under
# `set -o pipefail`, where a grep that leaves early on a match turns the
# SIGPIPE it sends into a failed pipeline.
if command -v bat >/dev/null 2>&1; then
  mc_want="Catppuccin $(theme_title "$(theme_current)")"
  mc_have="$(bat --list-themes 2>/dev/null || true)"
  case "$mc_have" in
    *"$mc_want"*) report ok "bat theme" "$mc_want" ;;
    *) report warn "bat theme" "run: bat cache --build" ;;
  esac
fi

true
