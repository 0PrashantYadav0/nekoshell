# anime

## What it does

Gives the greeting a random anime picture: an image provider for the
[greet](../greet/README.md) plugin, which hands the picture to fastfetch to
draw inline next to the machine stats, with the character's name on the
"Art" line. A new picture on every terminal you open. The pack is about fifty
PNG stills, fetched at install time from its own repository, pinned to a
commit.

Pictures need a terminal that can draw them: iTerm2, kitty, Ghostty and Warp
can, Terminal.app cannot. Where it cannot, this provider is never picked and
the others keep their turns; the doctor says so.

Three keys in `~/.config/nekoshell/greet.conf`: `ANIME_ONLY="miku gojo"`
draws only pictures whose file name contains one of the words, `ANIME_SKIP`
lists words never drawn (one file name in the pack is skipped unless you set
this), and `ANIME_HEIGHT` is the height in rows, `IMAGE_HEIGHT` (14) unless
set; the width follows the picture's proportions. `nekoshell greet --art
anime` forces one now.

## Installs

Nothing from Homebrew. The install hook downloads the pack's archive at the
pinned commit, shrinks every picture to 640 px on its long side with macOS's
`sips` (a picture is decoded on every shell start, and the originals are up
to 3500 px), keeps the shrunk copies in `~/.local/share/fastfetch-pngs` with
each one's size written down in `.nekoshell-list.txt`, and drops the rest.
The download is about 185 MB once; under 20 MB stay. Offline, it warns and the
greeting skips this provider.

## Files

None of yours. The keys above live in greet's `greet.conf`, and the pack lives
under `~/.local/share`. nekoshell ships no anime stills: they come from the
pack at install time and belong to their rights holders.

## After install

Nothing. Open a new terminal; with `ART=auto` the pictures take turns with
the other enabled providers. `ART="anime"` makes them the only art.

## Remove

`nekoshell plugin remove anime` takes the pictures out of the rotation. The
pack stays; `rm -rf ~/.local/share/fastfetch-pngs` drops it.
