#!/usr/bin/env bash
# minecraft doctor: the block pack and how many blocks it holds.

mc_pack="${MINECRAFT_PACK:-default-1.8.9}"
mc_dir="$HOME/.local/share/minecraft-colorscripts/colorscripts/$mc_pack"
if [[ -d "$mc_dir" ]]; then
  mc_n="$(find "$mc_dir" -name '*.txt' | wc -l | tr -d ' ')"
  report ok "minecraft-colorscripts" "$mc_pack, $mc_n blocks"
else
  report fail "minecraft-colorscripts" "missing (nekoshell plugin add minecraft)"
fi

true
