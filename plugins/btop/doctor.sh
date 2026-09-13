#!/usr/bin/env bash
# btop doctor: the binary, and whether btop.conf names a theme we ship.

if command -v btop >/dev/null 2>&1; then
  report ok "tool: btop" "$(command -v btop)"
else
  report fail "tool: btop" "missing (nekoshell plugin add btop)"
fi

bt_conf="$HOME/.config/btop/btop.conf"
if [[ -f "$bt_conf" ]] && grep -q "^color_theme = \"catppuccin_$FLAVOR\"" "$bt_conf"; then
  report ok "btop theme" "catppuccin_$FLAVOR"
else
  report warn "btop theme" "not set to catppuccin_$FLAVOR (run: nekoshell theme $FLAVOR)"
fi

true
