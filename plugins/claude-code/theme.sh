#!/usr/bin/env bash
# claude-code theme: a Catppuccin theme for Claude Code, the status line
# script, and the two settings that point Claude Code at them.
#
# The theme is a custom theme file under ~/.claude/themes/, which Claude
# Code watches and reloads; its base preset is light for latte and dark for
# the rest, which the template cannot know, so that one word is filled in
# after the render. The settings.json keys are set one at a time with the
# previous values recorded, so the uninstall hook can put them back.
# shellcheck source=plugins/ai/lib.sh
source "$NEKOSHELL_PLUGINS_DIR/ai/lib.sh"

cc_base="dark"
[[ "$FLAVOR" == "latte" ]] && cc_base="light"
cc_themes="$HOME/.claude/themes"
cc_theme="$cc_themes/nekoshell.json"
cc_status="$NEKOSHELL_CONFIG/ai/claude-statusline.sh"
cc_prev="$NEKOSHELL_CONFIG/ai/claude-previous.json"

mkdir -p "$cc_themes" "$NEKOSHELL_CONFIG/ai"
theme_render_template "$PLUGIN_DIR/files/theme.json.tmpl" "$cc_theme.render" "$FLAVOR"
sed "s/@@BASE@@/$cc_base/" "$cc_theme.render" >"$cc_theme.tmp" && mv "$cc_theme.tmp" "$cc_theme"
rm -f "$cc_theme.render"

theme_render_template "$PLUGIN_DIR/files/statusline.sh.tmpl" "$cc_status" "$FLAVOR"
chmod +x "$cc_status"

ai_json_set "$HOME/.claude/settings.json" theme '"custom:nekoshell"' "$cc_prev"
ai_json_set "$HOME/.claude/settings.json" statusLine "{\"type\": \"command\", \"command\": \"$cc_status\"}" "$cc_prev"

true
