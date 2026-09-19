# pure

## What you get

The pure prompt instead of Starship: a single line with the path in blue, the git branch and a `*` when the tree is dirty, arrows for commits ahead of or behind the remote, the last command's duration when it ran for more than five seconds, and a `❯` in the flavour's mauve that turns red after a failing command. Everything is drawn in the flavour's colours. It is the lightest of the three prompts nekoshell offers (Starship, Powerlevel10k through the p10k plugin, and this one).

## Using it

| Command | What it does |
| --- | --- |
| `nekoshell plugin add pure` | switch to pure (refuses while p10k is enabled: remove that first) |
| `nekoshell plugin remove pure` | back to Starship |
| `nekoshell doctor --plugin pure` | is the prompt function there, are the colours rendered |

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.config/nekoshell/pure-colors.zsh` | rendered on add and on every theme switch | no: edit `plugins/pure/files/pure-colors.zsh.tmpl` instead |

## Theme

The zstyles pure reads for its colours are rendered from the palette: the path in blue, git in overlay grey, arrows and stash in teal, actions and durations in yellow, the prompt character in mauve and red. A new shell picks up a switch.

## Turning it off

`nekoshell plugin remove pure`; Starship takes the prompt back in the next shell. `--purge` also uninstalls the pure formula.
