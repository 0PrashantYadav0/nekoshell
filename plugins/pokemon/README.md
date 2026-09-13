# pokemon

## What it does

Gives the greeting a random Pokémon: an art provider for the
[greet](../greet/README.md) plugin, which draws it next to the machine stats.
The "Art" line carries the Pokémon's name, number, type and generation from
`data/pokemon.tsv`; 1 in `POKEMON_SHINY_ODDS` is shiny (128), and
`POKEMON_GENERATIONS` (`"1-3"` or `"1,4"`) restricts the draw. Both keys go in
`~/.config/nekoshell/greet.conf`.

Every profile enables it, so a fresh install shows Pokémon unless asked
otherwise. `nekoshell greet --art pokemon` forces one now.

## Installs

[pokemon-colorscripts](https://gitlab.com/phoneybadger/pokemon-colorscripts),
which is not in Homebrew: it is checked out at a pinned commit into
`~/.local/share/pokemon-colorscripts` and symlinked onto your PATH at
`~/.local/bin/pokemon-colorscripts`. Nothing from Homebrew.

## Files

None of yours. The two keys above live in greet's `greet.conf`, and the
sprite pack lives under `~/.local/share`. nekoshell ships no Pokémon sprites:
they come from pokemon-colorscripts at greeting time, and Pokémon is a
trademark of The Pokémon Company.

## After install

Nothing. Open a new terminal and a Pokémon is there.

## Remove

`nekoshell plugin remove pokemon` takes the Pokémon out of the rotation. The
checkout stays; `rm -rf ~/.local/share/pokemon-colorscripts
~/.local/bin/pokemon-colorscripts` drops it.
