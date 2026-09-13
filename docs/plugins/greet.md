# greet

## What you get

Every new interactive shell prints a picture next to the machine stats fastfetch collects: OS, host, uptime, shell, terminal, CPU, memory, storage, battery, Wi-Fi, IP, packages, and an "Art" line naming the picture. The picture is a random Pokémon sprite from pokemon-colorscripts most of the time and an image from your art pack the rest, when the terminal can draw inline images (iTerm2, kitty, Ghostty and Warp can; Terminal.app cannot, so it always gets a Pokémon). The "Art" line carries the Pokémon's name, number, type and generation; 1 in 128 Pokémon is shiny.

The greeting stays silent inside tmux, inside the music panel, over SSH, under Claude Code, when stdout is not a terminal, and when `NEKOSHELL_NO_GREET` is set. It is the last thing the shell sources, so nothing is drawn over it. The doctor times it and warns above 150 ms.

## Using it

| Command | What it does |
| --- | --- |
| `nekoshell greet` (alias `greet`) | print the greeting now, rolling for Pokémon or art |
| `nekoshell greet --image` | use the art pack, if this terminal can draw images |
| `nekoshell greet --text` | use a Pokémon sprite whatever the terminal |
| `nekoshell art list` | files in the art pack |
| `nekoshell art add IMAGE` | copy a PNG or JPG into the pack |
| `nekoshell art sample` | copy the three shipped samples (neko, ghost, slime) into the pack |

Environment variables the greeting reads:

| Variable | Effect |
| --- | --- |
| `NEKOSHELL_NO_GREET=1` | no greeting |
| `NEKOSHELL_GREET_SSH=1` | greet over SSH too; exactly `1`, any other value keeps it silent |
| `NEKOSHELL_GREET_MODE=image` or `text` | what `--image` and `--text` set |
| `NEKOSHELL_GREET_TIME=1` | print `greet: N ms` after the greeting |
| `NEKOSHELL_SEED=N` | seed the roll, so the same Pokémon comes up each time |

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.config/nekoshell/greet.conf` | copied once | yes: `POKEMON_SHARE` (percent of shells that show a Pokémon, 70), `SHINY_ODDS` (1 in N, 128), `GENERATIONS` (`"1-3"` or `"1,4"`, empty for all), `IMAGE_WIDTH` and `IMAGE_HEIGHT` (art size in cells, 28 by 14) |
| `~/.config/nekoshell/art/` | yours | yes; `nekoshell art add` puts files here |
| `~/.config/fastfetch/config.jsonc` | rendered on add and on every theme switch | no: edit `plugins/greet/fastfetch.jsonc.tmpl` instead. A config of your own at that path is backed up before the first render |
| `~/.cache/nekoshell/art-name` | written on every greeting | no; it is the "Art" line |
| `~/.local/share/pokemon-colorscripts/`, `~/.local/bin/pokemon-colorscripts` | cloned at a pinned commit by the install hook | no |

## Theme

The fastfetch template carries two colours, the flavour's mauve for the keys and blue for the title; the theme hook renders it with those values on every `nekoshell theme <flavour>`. The Pokémon sprites and your images are drawn as they are.

## Turning it off

`nekoshell plugin remove greet` stops the greeting and removes `nekoshell greet` and `nekoshell art`. `greet.conf`, the art pack, the rendered fastfetch config and the pokemon-colorscripts checkout stay. `--purge` also uninstalls fastfetch unless another enabled plugin needs it. To keep the plugin but silence one shell, export `NEKOSHELL_NO_GREET=1`.
