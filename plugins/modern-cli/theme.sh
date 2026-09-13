#!/usr/bin/env bash
# modern-cli theme: bat reads themes from a cache it builds itself, not from
# ~/.config/bat/themes, so the vendored tmTheme files stay invisible until the
# cache is rebuilt. Quiet and best effort: a bat that cannot build a cache is a
# plain bat, not a broken install.

if command -v bat >/dev/null 2>&1; then
  run_quiet bat cache --build || log_warn "bat cache --build failed; bat keeps its old themes"
fi

true
