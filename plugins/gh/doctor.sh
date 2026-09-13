#!/usr/bin/env bash
# gh doctor: the binary, and whether it is logged in.

if command -v gh >/dev/null 2>&1; then
  report ok "tool: gh" "$(command -v gh)"
  if gh auth status >/dev/null 2>&1; then
    report ok "gh auth" "logged in"
  else
    report warn "gh auth" "not logged in (run: gh auth login)"
  fi
else
  report fail "tool: gh" "missing (nekoshell plugin add gh)"
fi

true
