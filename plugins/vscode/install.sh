#!/usr/bin/env bash
# vscode install: two keys in VS Code's user settings. terminal.external.osxExec
# names the app "Open in External Terminal" (Ctrl+Shift+C, the Explorer's
# context menu) hands to `open -a`, and terminal.explorerKind = "both" makes
# the Explorer offer the external terminal next to the integrated one. VS
# Code watches the file, so the change applies without a restart.
#
# VS Code is not installed here (casks = []): a Mac without it gets a warning
# and, when its settings directory is not there either, no file at all.
# shellcheck source=plugins/vscode/lib.sh
source "$PLUGIN_DIR/lib.sh"

if ! vscode_installed && [[ ! -d "$(dirname "$VSCODE_SETTINGS")" ]]; then
  log_warn "$PLUGIN_NAME: VS Code is not installed ($VSCODE_CASK); nothing written"
else
  vscode_installed || log_warn "$PLUGIN_NAME: VS Code is not installed ($VSCODE_CASK); its settings are written anyway"
  vs_term="$(config_get terminal 2>/dev/null || true)"
  if vs_app="$(vscode_app_for "$vs_term")"; then
    vscode_json_set "$VSCODE_SETTINGS" terminal.external.osxExec "\"$vs_app\"" "$VSCODE_PREVIOUS"
    log_ok "$PLUGIN_NAME: terminal.external.osxExec = $vs_app ($vs_term)"
  else
    log_warn "$PLUGIN_NAME: no VS Code app name is known for terminal '${vs_term:-none}'; nekoshell vscode terminal <id|App.app> sets one"
  fi
  vscode_json_set "$VSCODE_SETTINGS" terminal.explorerKind '"both"' "$VSCODE_PREVIOUS"
  log_ok "$PLUGIN_NAME: terminal.explorerKind = both"
fi

true
