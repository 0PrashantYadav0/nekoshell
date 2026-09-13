#!/usr/bin/env bash
# opencode theme: a Catppuccin theme file for OpenCode and the tui.json key
# that selects it. The theme's defs are the palette roles, so one template
# serves every flavour; the previous theme setting is recorded so the
# uninstall hook can put it back.
# shellcheck source=plugins/ai/lib.sh
source "$NEKOSHELL_PLUGINS_DIR/ai/lib.sh"

oc_dir="$HOME/.config/opencode"
mkdir -p "$oc_dir/themes" "$NEKOSHELL_CONFIG/ai"
theme_render_template "$PLUGIN_DIR/files/theme.json.tmpl" "$oc_dir/themes/nekoshell.json" "$FLAVOR"
ai_json_set "$oc_dir/tui.json" theme '"nekoshell"' "$NEKOSHELL_CONFIG/ai/opencode-previous.json"

true
