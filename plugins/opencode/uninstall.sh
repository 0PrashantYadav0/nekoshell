#!/usr/bin/env bash
# opencode uninstall: put the theme setting back and remove the theme file we
# rendered. OpenCode itself goes only with --purge, through the core.
# shellcheck source=plugins/ai/lib.sh
source "$NEKOSHELL_PLUGINS_DIR/ai/lib.sh"

ai_json_restore "$HOME/.config/opencode/tui.json" theme "$NEKOSHELL_CONFIG/ai/opencode-previous.json"
run rm -f "$HOME/.config/opencode/themes/nekoshell.json"

true
