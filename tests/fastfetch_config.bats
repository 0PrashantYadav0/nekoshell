#!/usr/bin/env bats
load helpers

CFG="$REPO_ROOT/stow/config/.config/fastfetch/config.jsonc"

@test "fastfetch config is valid JSONC with the expected rows in order" {
  run bash -c "sed -e 's://[^\"]*\$::' '$CFG' | python3 -c '
import json,sys
d=json.load(sys.stdin)
rows=[m if isinstance(m,str) else m[\"type\"] for m in d[\"modules\"]]
print(\" \".join(rows))
print(d[\"display\"][\"color\"][\"keys\"])'"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "title separator os host uptime shell terminal cpu memory disk battery wifi localip packages command break colors" ]
  [ "${lines[1]}" = "38;2;203;166;247" ]
}

@test "fastfetch accepts the config" {
  command -v fastfetch >/dev/null || skip "fastfetch not installed"
  run fastfetch --config "$CFG" --logo none --pipe
  [ "$status" -eq 0 ]
  [[ "$output" == *"Storage"* ]]
  [[ "$output" == *"Packages"* ]]
}
