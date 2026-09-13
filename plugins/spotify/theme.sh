#!/usr/bin/env bash
# spotify theme: render theme.toml in this flavour and point app.toml at it.
#
# theme.toml is nekoshell's: rendered from files/theme.toml.tmpl, overwritten
# on every flavour switch, and named catppuccin_<flavour> so app.toml can pick
# it by name. app.toml is the user's: the one `theme = "..."` line is rewritten
# to the new name, and only when the line is there to rewrite. Nothing else in
# the file is touched, and a line the user removed is not put back.
# shellcheck source=plugins/spotify/lib.sh
source "$PLUGIN_DIR/lib.sh"

mkdir -p "$SP_CONFIG_DIR"
# theme.toml used to be linked into the checkout. A render through the link
# would write into the repo, and after the update the link is broken anyway.
theme_clear_stale_link "$SP_THEME_TOML"
# A theme.toml the user wrote goes into the backup set before ours replaces
# it; one we rendered is skipped, so a flavour switch does not copy our own
# output into the backups.
theme_backup_foreign "$SP_THEME_TOML"
theme_render_template "$PLUGIN_DIR/files/theme.toml.tmpl" "$SP_THEME_TOML" "$FLAVOR"

# Only a real file is edited: a symlink here is either the stale link the
# install hook is about to replace, or the user's own dotfiles, and rewriting
# through either would put a file where their link was.
if [[ -f "$SP_APP_TOML" && ! -L "$SP_APP_TOML" ]] && sp_toml_has "$SP_APP_TOML" theme; then
  if [[ "$(sp_toml_value "$SP_APP_TOML" theme)" != "catppuccin_$FLAVOR" ]]; then
    sp_toml_set "$SP_APP_TOML" theme "catppuccin_$FLAVOR"
  fi
fi

true
