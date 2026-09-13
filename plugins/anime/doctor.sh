#!/usr/bin/env bash
# anime doctor: the pack, its version and how many sprites it holds.

an_dir="$HOME/.local/share/anime-colorscripts"
if [[ -d "$an_dir/colorscripts" ]]; then
  an_n="$(find "$an_dir/colorscripts" -name '*.txt' | wc -l | tr -d ' ')"
  an_fit="$(grep -c . "$an_dir/.nekoshell-list.txt" 2>/dev/null || echo 0)"
  report ok "anime-colorscripts" "$(cat "$an_dir/.nekoshell-version" 2>/dev/null || echo unknown), $an_fit of $an_n sprites fit"
else
  report fail "anime-colorscripts" "missing (nekoshell plugin add anime)"
fi

true
