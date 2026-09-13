# colorscripts

## What it does

Gives the greeting an ANSI pattern: an art provider for the
[greet](../greet/README.md) plugin. The patterns come from
[theamallalgi/colorscripts](https://github.com/theamallalgi/colorscripts),
a collection in the tradition of DT's shell-color-scripts: blocks, bars,
Pac-Man, space invaders, TIE fighters, drawn with the terminal's own sixteen
colours. That is what makes them different from the other providers: they
follow the flavour, because the flavour sets those colours.

Only the scripts named in `scripts.txt` beside this README are ever run.
They were read and timed at the pinned commit, none animates or waits, and
each draws in a few milliseconds. `nekoshell greet --art colorscripts` forces
one now.

## Installs

Nothing from Homebrew. The collection is checked out at a pinned commit
into `~/.local/share/colorscripts`; nothing goes onto your PATH.

## Files

None of yours. The checkout lives under `~/.local/share`.

## After install

Nothing. Open a new terminal; with `ART=auto` the patterns take turns with
the other enabled providers.

## Remove

`nekoshell plugin remove colorscripts` takes the patterns out of the
rotation. The checkout stays; `rm -rf ~/.local/share/colorscripts` drops it.
