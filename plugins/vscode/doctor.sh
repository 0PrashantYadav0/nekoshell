#!/usr/bin/env bash
# vscode doctor: VS Code itself, the external terminal it opens, and whether
# the debug console can use that terminal too.
# shellcheck source=plugins/vscode/lib.sh
source "$PLUGIN_DIR/lib.sh"

if vscode_installed; then
  report ok "tool: code" "$(vscode_installed_where)"
else
  report warn "tool: code" "not installed ($VSCODE_CASK)"
fi

# The value is JSON; the quotes come off for the rows.
vs_app="$(vscode_json_get "$VSCODE_SETTINGS" terminal.external.osxExec)"
vs_app="${vs_app#\"}"
vs_app="${vs_app%\"}"
vs_term="$(config_get terminal 2>/dev/null || true)"
if [[ -n "$vs_app" ]]; then
  report ok "external terminal" "$vs_app ($vs_term)"
elif ! vscode_installed; then
  report warn "external terminal" "not set and VS Code not installed"
elif vscode_app_for "$vs_term" >/dev/null; then
  report fail "external terminal" "not set while VS Code is installed (run: nekoshell vscode terminal $vs_term)"
else
  # Not a fail: nekoshell has no app name for this terminal, so the install
  # hook could not have set one; only the user can.
  report warn "external terminal" "not set: no VS Code app name is known for '${vs_term:-none}' (run: nekoshell vscode terminal <id|App.app>)"
fi

# VS Code scripts the debug console's external terminal itself and knows
# Terminal.app, iTerm.app and Ghostty.app only. With no app set it falls back
# to Terminal.app, which works.
if [[ -z "$vs_app" ]]; then
  report ok "debug console" "Terminal.app (VS Code's default)"
elif vscode_debug_supported "$vs_app"; then
  report ok "debug console" "$vs_app"
else
  report warn "debug console" "\"console\": \"externalTerminal\" in launch.json is not supported by VS Code for $vs_app"
fi

true
