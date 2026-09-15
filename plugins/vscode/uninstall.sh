#!/usr/bin/env bash
# vscode uninstall: put the two settings back the way they were. A key that
# was absent before is removed. VS Code itself is not touched: the plugin
# never installed it.
# shellcheck source=plugins/vscode/lib.sh
source "$PLUGIN_DIR/lib.sh"

vscode_json_restore "$VSCODE_SETTINGS" terminal.external.osxExec "$VSCODE_PREVIOUS"
vscode_json_restore "$VSCODE_SETTINGS" terminal.explorerKind "$VSCODE_PREVIOUS"

true
