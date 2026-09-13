#!/usr/bin/env bash
# colorscripts doctor: the checkout, and how many of the vetted scripts it holds.

cs_dir="$HOME/.local/share/colorscripts/colorscripts"
cs_list="$PLUGIN_DIR/scripts.txt"
cs_total="$(grep -c . "$cs_list" 2>/dev/null || echo 0)"
if [[ -d "$cs_dir" ]]; then
  cs_n=0
  while IFS= read -r cs_name; do
    [[ -n "$cs_name" && -f "$cs_dir/$cs_name" ]] && cs_n=$((cs_n + 1))
  done <"$cs_list"
  if ((cs_n > 0)); then
    report ok "colorscripts" "$cs_n of $cs_total scripts"
  else
    report fail "colorscripts" "none of the $cs_total vetted scripts is there (nekoshell plugin add colorscripts)"
  fi
else
  report fail "colorscripts" "missing (nekoshell plugin add colorscripts)"
fi

true
