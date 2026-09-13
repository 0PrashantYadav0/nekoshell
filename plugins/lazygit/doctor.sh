#!/usr/bin/env bash
# lazygit doctor: the binary is the whole plugin.

if command -v lazygit >/dev/null 2>&1; then
  report ok "tool: lazygit" "$(command -v lazygit)"
else
  report fail "tool: lazygit" "missing (nekoshell plugin add lazygit)"
fi

true
