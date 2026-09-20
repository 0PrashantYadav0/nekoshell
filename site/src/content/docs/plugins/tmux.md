# tmux

## What you get

tmux with a config copied into your home once: `t` attaches to a session named `main`, creating it the first time; the prefix is `C-a`, with `C-b` kept as a second prefix; panes split and move with vim letters; the mouse works; the status line sits at the top, drawn by catppuccin/tmux in the flavour the rest of the rig wears, with the directory, the session and the time on the right. TPM is cloned at a pinned commit; press `C-a I` once inside tmux to fetch tmux-sensible, tmux-yank and catppuccin/tmux v2.3.0.

Windows and panes count from 1 and are renumbered when one closes; 50000 lines of history; a 10 ms escape time; focus events on; `tmux-256color` with RGB.

## Using it

| Key | Does |
| --- | --- |
| `t` (shell alias) | `tmux new-session -A -s main` |
| `C-a` | the prefix |
| `C-a C-a` | send a literal `C-a` to the pane |
| `C-a r` | reload `tmux.conf` |
| `C-a \|` | split left and right, in the current path |
| `C-a -` | split top and bottom, in the current path |
| `C-a h`, `j`, `k`, `l` | move to the pane left, below, above, right |
| `C-a H`, `J`, `K`, `L` | resize by 5 that way; repeatable |
| `C-a c` | new window in the current path |
| `C-a I` | TPM: install the plugins, the first time and after adding one |
| copy mode | vi keys (`mode-keys vi`) |

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.config/tmux/tmux.conf` | copied once | yes; nekoshell never writes it again |
| `~/.config/tmux/nekoshell-theme.conf` | rendered on add and on every theme switch | no; one line, `set -g @catppuccin_flavor "<flavour>"` |
| `~/.config/tmux/plugins/tpm/` | cloned by the install hook | no; TPM's own |
| `~/.config/tmux/plugins/` | where TPM puts the plugins (`TMUX_PLUGIN_MANAGER_PATH`) | no |

If `~/.tmux.conf` or `~/.config/tmux/tmux.conf` exists already, nothing is copied and the add says so; the shipped file stays under `plugins/tmux/files/copy/`. The shipped config sources every `~/.config/tmux/nekoshell-*.conf` it finds, so a generated file can change the flavour without touching your config.

## Theme

`nekoshell theme <flavour>` rewrites `nekoshell-theme.conf`; a running server does not re-read it on its own. Press `C-a r`, or start a new server, to see the new status line. The window status style is `rounded` and the clock shows `%H:%M`. The doctor has `tmux theme` (the flavour in the file) and `tpm` rows beside `tool: tmux`.

## Turning it off

`nekoshell plugin remove tmux` drops the `t` alias; `tmux.conf`, the theme file and the TPM clone stay. `--purge` also uninstalls tmux unless another enabled plugin needs it.
