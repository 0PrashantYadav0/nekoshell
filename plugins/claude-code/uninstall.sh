#!/usr/bin/env bash
# claude-code uninstall: put the two settings back the way they were and
# remove the theme and status line files we rendered. Claude Code itself is
# not touched: the plugin never installed it.
# shellcheck source=plugins/ai/lib.sh
source "$NEKOSHELL_PLUGINS_DIR/ai/lib.sh"

cc_prev="$NEKOSHELL_CONFIG/ai/claude-previous.json"
ai_json_restore "$HOME/.claude/settings.json" statusLine "$cc_prev"
ai_json_restore "$HOME/.claude/settings.json" theme "$cc_prev"
run rm -f "$HOME/.claude/themes/nekoshell.json" "$NEKOSHELL_CONFIG/ai/claude-statusline.sh"

true
