#!/usr/bin/env bash
# yazi uninstall: take back the theme.toml we rendered. Only one whose header
# names nekoshell goes; a theme of the user's own at that path is left alone,
# and yazi.toml is theirs from the moment it was copied.

yz_theme="$HOME/.config/yazi/theme.toml"
if theme_is_rendered "$yz_theme"; then
  run rm -f "$yz_theme"
fi

true
