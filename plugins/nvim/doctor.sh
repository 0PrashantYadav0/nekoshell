#!/usr/bin/env bash
# nvim doctor: the binary is the whole plugin. The config it copied is the
# user's own file from the moment it lands, so there is nothing there to check.

if command -v nvim >/dev/null 2>&1; then
  report ok "tool: nvim" "$(command -v nvim)"
else
  report fail "tool: nvim" "missing (nekoshell plugin add nvim)"
fi

true
