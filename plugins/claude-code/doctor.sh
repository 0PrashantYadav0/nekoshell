#!/usr/bin/env bash
# claude-code doctor: the binary, the theme file and the setting that names
# it, the status line script and the setting that names it.
# shellcheck source=plugins/ai/lib.sh
source "$NEKOSHELL_PLUGINS_DIR/ai/lib.sh"

if command -v claude >/dev/null 2>&1; then
  report ok "tool: claude" "$(command -v claude)"
else
  report warn "tool: claude" "not installed (brew install --cask claude-code)"
fi

cc_title="$(printf '%s' "${FLAVOR:0:1}" | tr '[:lower:]' '[:upper:]')${FLAVOR:1}"
cc_theme="$HOME/.claude/themes/nekoshell.json"
if [[ -r "$cc_theme" ]] && grep -q "nekoshell $cc_title" "$cc_theme" \
  && [[ "$(ai_json_get "$HOME/.claude/settings.json" theme)" == '"custom:nekoshell"' ]]; then
  report ok "claude theme" "$FLAVOR (custom:nekoshell)"
else
  report fail "claude theme" "not rendered for $FLAVOR or not selected (run: nekoshell theme $FLAVOR)"
fi

cc_status="$NEKOSHELL_CONFIG/ai/claude-statusline.sh"
if [[ -x "$cc_status" ]] && [[ "$(ai_json_get "$HOME/.claude/settings.json" statusLine)" == *"$cc_status"* ]]; then
  report ok "claude status line" "$cc_status"
else
  report fail "claude status line" "not rendered or not selected (run: nekoshell theme $FLAVOR)"
fi

true
