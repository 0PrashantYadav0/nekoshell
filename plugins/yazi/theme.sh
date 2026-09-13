#!/usr/bin/env bash
# yazi theme: render theme.toml in this flavour.
#
# yazi reads theme.toml beside yazi.toml and has no flavour switch of its
# own, so the colours are baked in at render time. The rendered file is
# nekoshell's, not the user's: it is overwritten on every flavour switch,
# which is why the template beside this hook is the thing to edit. A
# theme.toml of the user's own is backed up before the first render.

mkdir -p "$HOME/.config/yazi"
theme_clear_stale_link "$HOME/.config/yazi/theme.toml"
theme_backup_foreign "$HOME/.config/yazi/theme.toml"
theme_render_template "$PLUGIN_DIR/files/theme.toml.tmpl" "$HOME/.config/yazi/theme.toml" "$FLAVOR"

true
