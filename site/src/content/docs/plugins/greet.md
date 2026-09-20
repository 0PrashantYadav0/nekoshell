# greet

## What you get

Every new interactive shell prints a picture next to the machine stats fastfetch collects: OS, host, uptime, shell, terminal, CPU, memory, storage, battery, Wi-Fi, IP, packages, and an "Art" line naming the picture. The picture is art from one of the enabled art provider plugins most of the time and an image from your art pack the rest, when the terminal can draw inline images (iTerm2, kitty, Ghostty and Warp can; Terminal.app cannot, so it always gets a sprite). With no provider enabled the stats print on their own.

The greeting stays silent inside tmux, inside the music panel, over SSH, under Claude Code, when stdout is not a terminal, and when `NEKOSHELL_NO_GREET` is set. It is the last thing the shell sources, so nothing is drawn over it. The doctor times it and warns above 150 ms.

See the README's [Screenshots](../../README.md#screenshots) section for the greeting next to three of the art providers.

## Art providers

The art comes from an enabled plugin that ships a `greet-art` program, a sprite: [pokemon](pokemon.md) (in every profile), [minecraft](minecraft.md) and [colorscripts](colorscripts.md); or a `greet-image` program, a picture drawn inline: [anime](anime.md), which only takes its turn where the terminal can draw images. `ART` in `greet.conf` picks among them: `auto` gives each the same odds; `pokemon:70,anime:30` weights them; a name that is not enabled is skipped; a weight of 0 never draws. `nekoshell greet --art anime` forces one. Each provider's own settings go in `greet.conf` too, prefixed with its name (`POKEMON_SHINY_ODDS`, `ANIME_ONLY`); its page lists them. The doctor prints one row per enabled provider and warns when there is none.

## Using it

| Command | What it does |
| --- | --- |
| `nekoshell greet` (alias `greet`) | print the greeting now, rolling for a sprite or art |
| `nekoshell greet --image` | use the art pack, if this terminal can draw images |
| `nekoshell greet --text` | use a sprite whatever the terminal |
| `nekoshell greet --art NAME` | use that provider's sprite or picture |
| `nekoshell art list` | files in the art pack |
| `nekoshell art add IMAGE` | copy a PNG or JPG into the pack |
| `nekoshell art sample` | copy the three shipped samples (neko, ghost, slime) into the pack |

Environment variables the greeting reads:

| Variable | Effect |
| --- | --- |
| `NEKOSHELL_NO_GREET=1` | no greeting |
| `NEKOSHELL_GREET_SSH=1` | greet over SSH too; exactly `1`, any other value keeps it silent |
| `NEKOSHELL_GREET_MODE=image` or `text` | what `--image` and `--text` set |
| `NEKOSHELL_GREET_ART=NAME` | what `--art` sets |
| `NEKOSHELL_GREET_TIME=1` | print `greet: N ms` after the greeting |
| `NEKOSHELL_SEED=N` | seed the roll, so the same sprite comes up each time |

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.config/nekoshell/greet.conf` | copied once | yes: `ART` (`auto` or weights), `SPRITE_SHARE` (percent of shells that show a sprite, 70), `IMAGE_WIDTH` and `IMAGE_HEIGHT` (art pack image size in cells, 28 by 14; an image provider falls back on them too), and the providers' keys. `POKEMON_SHARE` from an older copy still works |
| `~/.config/nekoshell/art/` | yours | yes; `nekoshell art add` puts files here |
| `~/.config/fastfetch/config.jsonc` | rendered on add and on every theme switch | no: edit `plugins/greet/fastfetch.jsonc.tmpl` instead. A config of your own at that path is backed up before the first render |
| `~/.cache/nekoshell/art-name` | written on every greeting | no; it is the "Art" line |

## Theme

The fastfetch template carries two colours, the flavour's mauve for the keys and blue for the title; the theme hook renders it with those values on every `nekoshell theme <flavour>`. The sprites and your images are drawn as they are, except the colorscripts patterns, which use the terminal's palette and so follow the flavour.

## Turning it off

`nekoshell plugin remove greet` stops the greeting and removes `nekoshell greet` and `nekoshell art`; the provider plugins have to be removed first, since they need greet. `greet.conf`, the art pack and the rendered fastfetch config stay. `--purge` also uninstalls fastfetch unless another enabled plugin needs it. To keep the plugin but silence one shell, export `NEKOSHELL_NO_GREET=1`.
