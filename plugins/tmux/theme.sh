#!/usr/bin/env bash
# tmux theme: the flavour goes in a file of nekoshell's own, which the shipped
# tmux.conf sources along with every other nekoshell-*.conf. The config itself
# is the user's from the moment it is copied, so a flavour switch must never
# reach into it.
#
# A running server does not re-read anything on its own; `tmux source-file` is
# not run from here because the flavour only changes what the status line is
# drawn with, and the next `C-a r` (or the next server) picks it up.

mkdir -p "$HOME/.config/tmux"
printf 'set -g @catppuccin_flavor "%s"\n' "$FLAVOR" >"$HOME/.config/tmux/nekoshell-theme.conf"

true
