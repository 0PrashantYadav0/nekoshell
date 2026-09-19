# pokemon

## What you get

A random Pokémon sprite in the greeting, drawn by the [greet](greet.md) plugin next to the machine stats. The "Art" line names it with its Pokédex number, type and generation; 1 in 128 is shiny. Every profile enables this provider, so a fresh install shows Pokémon unless you ask for something else.

## Using it

| Command | What it does |
| --- | --- |
| `nekoshell greet --art pokemon` | a Pokémon now, whatever `ART` says |
| `nekoshell doctor --plugin pokemon` | is the sprite pack there and drawing |

Keys in `~/.config/nekoshell/greet.conf`:

| Key | Effect |
| --- | --- |
| `POKEMON_SHINY_ODDS=128` | 1 in N Pokémon is shiny; 0 for never |
| `POKEMON_GENERATIONS="1-3"` | only these generations (`"1,4"` works too); empty for all |

`SHINY_ODDS` and `GENERATIONS`, the names an older `greet.conf` used, still work.

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.local/share/pokemon-colorscripts/` | cloned at a pinned commit by the install hook | no |
| `~/.local/bin/pokemon-colorscripts` | a link into that checkout | no |
| `plugins/pokemon/data/pokemon.tsv` | in the checkout; generated from PokeAPI | no |

## Theme

None: the sprites are drawn in their own colours.

## Turning it off

`nekoshell plugin remove pokemon` takes the Pokémon out of the rotation; the greeting then draws from the other enabled providers, or prints the stats alone. The checkout under `~/.local/share` stays until you `rm -rf` it. `ART="anime"` in `greet.conf` keeps the plugin but stops drawing from it.
