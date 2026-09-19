# btop

## What you get

btop, a resource monitor with CPU, memory, disk, network and process views, history graphs and a mouse that works, on the `top` alias, in the current Catppuccin flavour.

## Using it

`top` runs `btop`; the keys inside are btop's own. The plugin adds nothing else.

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.config/btop/themes/catppuccin_{latte,frappe,macchiato,mocha}.theme` | linked | no |
| `~/.config/btop/btop.conf` | the `color_theme` line is written on add and on every theme switch; the file is created with that one line when missing | yes, everything else; btop rewrites the file itself when it exits |

## Theme

The theme hook sets `color_theme = "catppuccin_<flavour>"` and touches nothing else in `btop.conf`. The doctor's `btop theme` row warns when the line does not name the flavour in force, with `nekoshell theme <flavour>` as the fix.

## Turning it off

`nekoshell plugin remove btop` unlinks the four theme files and drops `top`; `btop.conf` stays as it is, `color_theme` line included. `--purge` also uninstalls the formula unless another enabled plugin needs it.
