# minecraft

## What you get

A random Minecraft block in the greeting, drawn by the [greet](greet.md) plugin next to the machine stats, with the block's name on the "Art" line. The pack is minecraft-colorscripts: 261 blocks from the 1.8.9 textures, checked out at a pinned commit.

## Using it

| Command | What it does |
| --- | --- |
| `nekoshell plugin add minecraft` | enable it (greet comes along if it is not enabled yet) |
| `nekoshell greet --art minecraft` | a block now, whatever `ART` says |
| `nekoshell doctor --plugin minecraft` | is the pack there, how many blocks |

Keys in `~/.config/nekoshell/greet.conf`:

| Key | Effect |
| --- | --- |
| `MINECRAFT_PACK=default-1.8.9` | the texture pack directory under the checkout; only this one ships |

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.local/share/minecraft-colorscripts/` | cloned at a pinned commit by the install hook | no |

## Theme

None: the blocks are drawn in their texture colours.

## Turning it off

`nekoshell plugin remove minecraft` takes the blocks out of the rotation; the checkout stays until you `rm -rf` it. To keep the plugin but pick other providers, set `ART` in `greet.conf`.
