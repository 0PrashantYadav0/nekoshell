# Assets

`neko.svg` is the project's mascot: a cat sitting on a terminal block, drawn in Catppuccin mocha on a 256 by 256 canvas, with no external references, no script and no font dependence, so it draws the same wherever it is opened. It is this repository's own drawing and carries the repository's MIT license, like everything here that [THIRD_PARTY.md](../../THIRD_PARTY.md) does not list. The README shows it at the top, 180 pixels wide, above the badge row; nothing at runtime reads it, so `.gitattributes` keeps this directory out of the release tarball.

Nothing needs a PNG of it, but if one is ever wanted, macOS renders the file with no other tool installed:

```bash
qlmanage -t -s 512 -o . docs/assets/neko.svg   # writes neko.svg.png
```
