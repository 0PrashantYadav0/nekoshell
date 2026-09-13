#!/usr/bin/env bash
# anime doctor: the pack, its version and how many sprites it holds.

an_dir="$HOME/.local/share/anime-colorscripts"
if [[ -d "$an_dir/colorscripts" ]]; then
  an_n="$(find "$an_dir/colorscripts" -name '*.txt' | wc -l | tr -d ' ')"
  report ok "anime-colorscripts" "$(cat "$an_dir/.nekoshell-version" 2>/dev/null || echo unknown), $an_n sprites"
else
  report fail "anime-colorscripts" "missing (nekoshell plugin add anime)"
fi

true
