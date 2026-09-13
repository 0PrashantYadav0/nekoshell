#!/usr/bin/env bash
# p10k theme: the flavour's colours for the prompt go in a file of nekoshell's
# own, which plugin.zsh sources before ~/.p10k.zsh. The config itself is the
# user's from the moment it is copied, so a flavour switch never edits it.

theme_render_template "$PLUGIN_DIR/files/p10k-colors.zsh.tmpl" "$NEKOSHELL_CONFIG/p10k-colors.zsh" "$FLAVOR"

true
