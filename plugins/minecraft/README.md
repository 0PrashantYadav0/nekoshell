# minecraft

## What it does

Gives the greeting a random Minecraft block: an art provider for the
[greet](../greet/README.md) plugin, which draws the block next to the machine
stats with its name on the "Art" line. The pack is
[minecraft-colorscripts](https://github.com/Axistorm1/minecraft-colorscripts),
261 blocks from the 1.8.9 textures as coloured unicode text.

`MINECRAFT_PACK` in `~/.config/nekoshell/greet.conf` names the texture pack
directory (`default-1.8.9`, the only one shipped). `nekoshell greet --art
minecraft` forces a block now.

## Installs

Nothing from Homebrew. The pack is checked out at a pinned commit into
`~/.local/share/minecraft-colorscripts`. Its launcher script is not used and
nothing goes onto your PATH.

## Files

None of yours. The pack lives under `~/.local/share`. nekoshell ships no
block textures: they come from the pack at greeting time, and Minecraft is a
trademark of Mojang.

## After install

Nothing. Open a new terminal; with `ART=auto` the blocks take turns with the
other enabled providers.

## Remove

`nekoshell plugin remove minecraft` takes the blocks out of the rotation. The
checkout stays; `rm -rf ~/.local/share/minecraft-colorscripts` drops it.
