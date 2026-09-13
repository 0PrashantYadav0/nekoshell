#!/usr/bin/env bash
# opencode doctor: the binary, the rendered theme and the setting that names it.
# shellcheck source=plugins/ai/lib.sh
source "$NEKOSHELL_PLUGINS_DIR/ai/lib.sh"

if command -v opencode >/dev/null 2>&1; then
  report ok "tool: opencode" "$(command -v opencode)"
else
  report fail "tool: opencode" "missing (nekoshell plugin add opencode)"
fi

oc_theme="$HOME/.config/opencode/themes/nekoshell.json"
oc_hex="$(theme_hexes "$FLAVOR" base 2>/dev/null || true)"
if [[ -r "$oc_theme" && -n "$oc_hex" ]] && grep -q "\"base\": \"#$oc_hex\"" "$oc_theme" \
  && [[ "$(ai_json_get "$HOME/.config/opencode/tui.json" theme)" == '"nekoshell"' ]]; then
  report ok "opencode theme" "$FLAVOR (nekoshell)"
else
  report fail "opencode theme" "not rendered for $FLAVOR or not selected (run: nekoshell theme $FLAVOR)"
fi

true
