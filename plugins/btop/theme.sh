#!/usr/bin/env bash
# btop theme: point btop at this flavour's vendored theme file.
#
# btop owns the rest of btop.conf and rewrites the whole file when it exits, so
# only the one line is ever touched here: anything else written into that file
# would be lost the next time the user quits btop, and anything the user set
# there has to survive a theme switch.

bt_conf="$HOME/.config/btop/btop.conf"
mkdir -p "$HOME/.config/btop"

if [[ ! -f "$bt_conf" ]]; then
  printf '#? Config file for btop v. 1.x, written by nekoshell.\ncolor_theme = "catppuccin_%s"\n' "$FLAVOR" >"$bt_conf"
elif grep -q '^color_theme' "$bt_conf"; then
  bt_tmp="$bt_conf.nekoshell.tmp"
  sed "s|^color_theme.*|color_theme = \"catppuccin_$FLAVOR\"|" "$bt_conf" >"$bt_tmp" && mv "$bt_tmp" "$bt_conf"
else
  printf 'color_theme = "catppuccin_%s"\n' "$FLAVOR" >>"$bt_conf"
fi

true
