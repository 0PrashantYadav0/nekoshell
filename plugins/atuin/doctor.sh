#!/usr/bin/env bash
# atuin doctor: the binary is the whole plugin.

if command -v atuin >/dev/null 2>&1; then
  report ok "tool: atuin" "$(command -v atuin)"
else
  report fail "tool: atuin" "missing (nekoshell plugin add atuin)"
fi

true
