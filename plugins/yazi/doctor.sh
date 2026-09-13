#!/usr/bin/env bash
# yazi doctor: the binary, and the theme rendered for the flavour in force.

if command -v yazi >/dev/null 2>&1; then
  report ok "tool: yazi" "$(command -v yazi)"
else
  report fail "tool: yazi" "missing (nekoshell plugin add yazi)"
fi

yz_title="$(printf '%s' "${FLAVOR:0:1}" | tr '[:lower:]' '[:upper:]')${FLAVOR:1}"
if [[ -r "$HOME/.config/yazi/theme.toml" ]] && head -n 3 "$HOME/.config/yazi/theme.toml" | grep -q "$yz_title"; then
  report ok "yazi theme" "$FLAVOR"
else
  report fail "yazi theme" "not rendered for $FLAVOR (run: nekoshell theme $FLAVOR)"
fi

true
