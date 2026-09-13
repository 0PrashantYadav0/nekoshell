# colorscripts

## What you get

An ANSI pattern in the greeting, drawn by the [greet](greet.md) plugin next to the machine stats: blocks, bars, Pac-Man, space invaders, TIE fighters and the rest of a collection in the tradition of DT's shell-color-scripts. They use the terminal's sixteen colours, so they follow the flavour by themselves. Only the 32 scripts on the plugin's vetted list are ever run; each was read and timed at the pinned commit and draws in a few milliseconds.

## Using it

| Command | What it does |
| --- | --- |
| `nekoshell plugin add colorscripts` | enable it (greet comes along if it is not enabled yet) |
| `nekoshell greet --art colorscripts` | a pattern now, whatever `ART` says |
| `nekoshell doctor --plugin colorscripts` | is the checkout there, how many of the vetted scripts it holds |

No keys of its own in `greet.conf`.

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.local/share/colorscripts/` | cloned at a pinned commit by the install hook | no |
| `plugins/colorscripts/scripts.txt` | in the checkout: the vetted list | only to add a script you have read |

## Theme

The patterns are drawn in the terminal's palette, which every adapter sets to the flavour, so a `nekoshell theme` switch recolours them in the next shell.

## Turning it off

`nekoshell plugin remove colorscripts` takes the patterns out of the rotation; the checkout stays until you `rm -rf` it. To keep the plugin but pick other providers, set `ART` in `greet.conf`.
