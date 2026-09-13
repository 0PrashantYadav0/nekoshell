#!/usr/bin/env bash
# fzf doctor: the binary is the whole plugin.

if command -v fzf >/dev/null 2>&1; then
  report ok "tool: fzf" "$(command -v fzf)"
else
  report fail "tool: fzf" "missing (nekoshell plugin add fzf)"
fi

true
