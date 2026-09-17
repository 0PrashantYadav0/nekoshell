#!/usr/bin/env bash
# anime doctor: the pack, its commit and how many pictures it holds; and a
# warning where the configured terminal cannot draw them at all.

an_dir="$HOME/.local/share/fastfetch-pngs"
if [[ -s "$an_dir/.nekoshell-list.txt" ]]; then
  an_n="$(grep -c . "$an_dir/.nekoshell-list.txt")"
  an_sha="$(cat "$an_dir/.nekoshell-version" 2>/dev/null || echo unknown)"
  report ok "anime pictures" "${an_sha:0:7}, $an_n pictures"
else
  report fail "anime pictures" "missing (nekoshell plugin add anime)"
fi

# The greeting only draws from this provider where the terminal adapter says
# it can draw images; elsewhere the plugin is enabled and never seen.
an_term="$(terminal_current 2>/dev/null || true)"
if [[ -n "$an_term" ]] && terminal_load "$an_term" >/dev/null 2>&1; then
  case " $(terminal_capabilities 2>/dev/null || true) " in
    *" images "*) ;;
    *) report warn "anime pictures" "the $an_term terminal cannot draw images; the greeting skips this provider there" ;;
  esac
fi

true
