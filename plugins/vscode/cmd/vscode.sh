#!/usr/bin/env bash
# vscode: show or change the terminal VS Code opens from "Open in External Terminal"
# shellcheck source=plugins/vscode/lib.sh
source "$PLUGIN_DIR/lib.sh"

usage_vscode() {
  cat <<USAGE
usage: nekoshell vscode terminal              the app VS Code opens, and its nekoshell id
       nekoshell vscode terminal ID|App.app   make VS Code open that terminal instead

ID is a nekoshell terminal id ($VSCODE_IDS); a name ending in
.app is written as it is, for a terminal nekoshell has no adapter for. The
key is terminal.external.osxExec in VS Code's settings.json; the value it
had before the first change is put back by nekoshell plugin remove vscode.
USAGE
}

# _vscode_terminal_show: the current value of terminal.external.osxExec, with
# the nekoshell id in parentheses when the app is one from the table.
_vscode_terminal_show() {
  local app id
  app="$(vscode_json_get "$VSCODE_SETTINGS" terminal.external.osxExec)"
  app="${app#\"}"
  app="${app%\"}"
  if [[ -z "$app" ]]; then
    echo "not set (VS Code opens Terminal.app)"
  elif id="$(vscode_id_for "$app")"; then
    echo "$app ($id)"
  else
    echo "$app"
  fi
}

# _vscode_terminal_set NAME: write the app for NAME, an id from the table or
# a bundle name of its own, recording the previous value the first time as
# the install hook does. Status 1 and nothing written for anything else.
_vscode_terminal_set() {
  local name="$1" app
  if ! app="$(vscode_app_for "$name")"; then
    case "$name" in
      ?*.app) app="$name" ;;
      *)
        log_fail "$name is not a terminal nekoshell knows ($VSCODE_IDS) and does not end in .app"
        return 1
        ;;
    esac
  fi
  vscode_json_set "$VSCODE_SETTINGS" terminal.external.osxExec "\"$app\"" "$VSCODE_PREVIOUS"
  # A dry run has said what it would do; the lines below describe a change.
  [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]] && return 0
  log_ok "VS Code opens $app"
  vscode_debug_supported "$app" \
    || log_warn "\"console\": \"externalTerminal\" in launch.json is not supported by VS Code for $app; the debug console keeps needing Terminal.app, iTerm.app or Ghostty.app"
}

cmd_vscode() {
  local sub="${1:-}"
  [[ $# -gt 0 ]] && shift
  case "$sub" in
    terminal)
      case $# in
        0) _vscode_terminal_show ;;
        1) _vscode_terminal_set "$1" ;;
        *)
          usage_vscode >&2
          return 2
          ;;
      esac
      ;;
    -h | --help | help)
      usage_vscode
      return 0
      ;;
    *)
      usage_vscode >&2
      return 2
      ;;
  esac
}
