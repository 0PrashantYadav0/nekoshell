# anime

## What you get

A random anime character in the greeting, drawn by the [greet](greet.md) plugin next to the machine stats, with the character's name on the "Art" line. The pack is anime-colorscripts, about 250 characters as coloured unicode text; the install hook downloads its pinned release and checks the checksum.

## Using it

| Command | What it does |
| --- | --- |
| `nekoshell plugin add anime` | enable it (greet comes along if it is not enabled yet) |
| `nekoshell greet --art anime` | an anime character now, whatever `ART` says |
| `nekoshell doctor --plugin anime` | is the pack there, which version, how many sprites |

Keys in `~/.config/nekoshell/greet.conf`:

| Key | Effect |
| --- | --- |
| `ANIME_ONLY="miku naruto"` | only characters whose file name contains one of the words |
| `ANIME_SKIP="word"` | never draw a name containing a word; the default skips the one crude file name in the pack |

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.local/share/anime-colorscripts/` | the release tarball, unpacked by the install hook; `.nekoshell-version` records which | no |
| `~/.local/share/anime-colorscripts/.nekoshell-list.txt` | written by the install hook: the sprites no wider than 80 columns, which is what the greeting draws from; the doctor says how many fit | no |

## Theme

None: the sprites are drawn in their own colours.

## Turning it off

`nekoshell plugin remove anime` takes the characters out of the rotation; the pack stays until you `rm -rf` it. To keep the plugin but pick other providers, set `ART` in `greet.conf`.
