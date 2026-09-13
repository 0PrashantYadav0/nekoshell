#!/usr/bin/env bash
# ai theme: the banner's two colours, rendered for the flavour in force.

mkdir -p "$NEKOSHELL_CONFIG/ai"
theme_render_template "$PLUGIN_DIR/files/colors.sh.tmpl" "$NEKOSHELL_CONFIG/ai/colors.sh" "$FLAVOR"

true
