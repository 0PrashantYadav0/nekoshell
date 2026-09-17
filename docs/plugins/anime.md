# anime

## What you get

A random anime picture in the greeting, on every terminal you open: the [greet](greet.md) plugin hands it to fastfetch, which draws it inline next to the machine stats, with the character's name on the "Art" line. The pack is about fifty PNG stills; the install hook fetches them once at a pinned commit and shrinks them so they draw fast.

Pictures need a terminal that can draw them: iTerm2, kitty, Ghostty and Warp can, Terminal.app cannot. Where it cannot, this provider is never picked and the other providers keep their turns; `nekoshell greet --art anime` says so, and the doctor warns.

## Using it

| Command | What it does |
| --- | --- |
| `nekoshell plugin add anime` | enable it (greet comes along if it is not enabled yet) |
| `nekoshell greet --art anime` | an anime picture now, whatever `ART` says |
| `nekoshell doctor --plugin anime` | is the pack there, which commit, how many pictures, and can this terminal draw them |

Keys in `~/.config/nekoshell/greet.conf`:

| Key | Effect |
| --- | --- |
| `ANIME_ONLY="miku gojo"` | only pictures whose file name contains one of the words |
| `ANIME_SKIP="word"` | never draw a file name containing a word; one file name in the pack is skipped unless you set this |
| `ANIME_HEIGHT=14` | how tall to draw, in rows; `IMAGE_HEIGHT` (14) unless set. The width follows the picture's proportions, so a portrait still at 14 rows is about 20 columns wide |

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.local/share/fastfetch-pngs/` | the pictures, shrunk to 640 px by the install hook; `.nekoshell-version` records the commit | no |
| `~/.local/share/fastfetch-pngs/.nekoshell-list.txt` | written by the install hook: each picture's name and pixel size, which is what the greeting draws from and sizes by | no |

## Theme

None: the pictures are drawn as they are.

## Turning it off

`nekoshell plugin remove anime` takes the pictures out of the rotation; the pack stays until you `rm -rf` it. To keep the plugin but pick other providers, set `ART` in `greet.conf`.
