# anime

## What it does

Gives the greeting a random anime character: an art provider for the
[greet](../greet/README.md) plugin, which draws the sprite next to the
machine stats with the character's name on the "Art" line. The pack is
[anime-colorscripts](https://github.com/juanlouisr/anime-colorscripts), some
250 characters as coloured unicode text.

Two keys in `~/.config/nekoshell/greet.conf`: `ANIME_ONLY="miku naruto"`
draws only characters whose name contains one of the words, and
`ANIME_SKIP` lists words never drawn (one file in the pack has a crude name,
which the default skips). `nekoshell greet --art anime` forces one now.

## Installs

Nothing from Homebrew. The pack's git tree holds no sprites, so the install
hook downloads the pinned release tarball (v1.1.3, checked against a
recorded sha256) into `~/.local/share/anime-colorscripts` and writes
`.nekoshell-list.txt` there: the sprites no wider than 80 columns, the ones
that fit next to the stats (a few in the pack are 250 columns wide). Offline,
it warns and the greeting skips this provider.

## Files

None of yours. The keys above live in greet's `greet.conf`, and the pack lives
under `~/.local/share`. nekoshell ships no anime stills: they come from the
pack at greeting time and belong to their rights holders.

## After install

Nothing. Open a new terminal; with `ART=auto` the anime characters take turns
with the other enabled providers. `ART="anime"` makes them the only sprite.

## Remove

`nekoshell plugin remove anime` takes the characters out of the rotation. The
pack stays; `rm -rf ~/.local/share/anime-colorscripts` drops it.
