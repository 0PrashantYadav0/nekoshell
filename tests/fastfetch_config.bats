#!/usr/bin/env bats
load helpers

setup() { setup_tmp_home; }
teardown() { teardown_tmp_home; }

TEMPLATE="$REPO_ROOT/templates/fastfetch.jsonc"

# render FLAVOUR: render templates/fastfetch.jsonc into $HOME the way the
# installer does. fastfetch never sees the template, only the rendered file.
render() {
  bash -c "source '$REPO_ROOT/lib/log.sh'
           source '$REPO_ROOT/lib/paths.sh'
           NEKOSHELL_ROOT='$REPO_ROOT'
           source '$REPO_ROOT/lib/theme.sh'
           theme_render_template '$TEMPLATE' '$HOME/config.jsonc' '$1'"
}

@test "fastfetch config is valid JSONC with the expected rows in order" {
  render mocha
  run bash -c "sed -e 's://[^\"]*\$::' '$HOME/config.jsonc' | python3 -c '
import json,sys
d=json.load(sys.stdin)
rows=[m if isinstance(m,str) else m[\"type\"] for m in d[\"modules\"]]
print(\" \".join(rows))
print(d[\"display\"][\"color\"][\"keys\"])
print(d[\"display\"][\"color\"][\"title\"])'"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "title separator os host uptime shell terminal cpu memory disk battery wifi localip packages command break colors" ]
  [ "${lines[1]}" = "38;2;203;166;247" ]
  [ "${lines[2]}" = "38;2;137;180;250" ]
}

# The colours are the only thing the flavour changes; the module list must not
# drift between flavours.
@test "latte renders the same rows with its own key and title colours" {
  render latte
  run bash -c "sed -e 's://[^\"]*\$::' '$HOME/config.jsonc' | python3 -c '
import json,sys
d=json.load(sys.stdin)
print(len(d[\"modules\"]))
print(d[\"display\"][\"color\"][\"keys\"])
print(d[\"display\"][\"color\"][\"title\"])'"
  [ "${lines[0]}" = "17" ]
  [ "${lines[1]}" = "38;2;136;57;239" ]
  [ "${lines[2]}" = "38;2;30;102;245" ]
}

@test "fastfetch accepts the config" {
  command -v fastfetch >/dev/null || skip "fastfetch not installed"
  render mocha
  run fastfetch --config "$HOME/config.jsonc" --logo none --pipe
  [ "$status" -eq 0 ]
  [[ "$output" == *"Storage"* ]]
  [[ "$output" == *"Packages"* ]]
}
