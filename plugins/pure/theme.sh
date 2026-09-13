#!/usr/bin/env bash
# pure theme: the flavour's colours for the prompt go in a file of nekoshell's
# own, which plugin.zsh sources before the prompt is set up.

theme_render_template "$PLUGIN_DIR/files/pure-colors.zsh.tmpl" "$NEKOSHELL_CONFIG/pure-colors.zsh" "$FLAVOR"

true
