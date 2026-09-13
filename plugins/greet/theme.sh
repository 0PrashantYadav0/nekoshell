#!/usr/bin/env bash
# greet theme: render the fastfetch config in this flavour.
#
# fastfetch reads one config file and has no theme of its own, so the colours
# are baked in at render time. The rendered file is nekoshell's, not the
# user's: it is overwritten on every flavour switch, which is why the template
# beside this hook is the thing to edit.

mkdir -p "$HOME/.config/fastfetch"
# The fastfetch config used to be stowed, and `stow --restow` leaves the old
# link behind. Rendering through it would write straight into the checkout.
theme_clear_stale_link "$HOME/.config/fastfetch/config.jsonc"
# A config of the user's own is theirs to get back: it goes into the backup set
# before the render writes over it. One we rendered is skipped, so a flavour
# switch does not keep copying our own output into the backups.
theme_backup_foreign "$HOME/.config/fastfetch/config.jsonc"
theme_render_template "$PLUGIN_DIR/fastfetch.jsonc.tmpl" "$HOME/.config/fastfetch/config.jsonc" "$FLAVOR"

true
