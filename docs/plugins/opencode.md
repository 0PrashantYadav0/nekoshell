# opencode

## What you get

OpenCode, the open-source AI coding agent, in the flavour: a theme with every colour key on a Catppuccin role, selected in `tui.json`, and the [ai](ai.md) plugin's welcome banner before every interactive session. A `nekoshell theme` switch re-renders the theme; restart OpenCode to see it.

## Using it

| Command | What it does |
| --- | --- |
| `opencode` | the banner, then OpenCode |
| `opencode run "..."`, `opencode serve`, `opencode auth ...` | untouched: no banner for non-interactive uses |
| `command opencode` | skip the wrapper entirely |
| `nekoshell doctor --plugin opencode` | the binary, the theme and the setting |

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.config/opencode/themes/nekoshell.json` | rendered on add and on every theme switch | no: edit `plugins/opencode/files/theme.json.tmpl` |
| `~/.config/opencode/tui.json` | one key touched in place: `theme`; the previous value is kept in `~/.config/nekoshell/ai/opencode-previous.json` and restored on removal | yes, everything else in it |

## Theme

The template's `defs` are the 26 palette roles and its `theme` block follows OpenCode's own catppuccin theme: primary blue, secondary mauve, accent pink, text and the overlay greys for muted text, base, mantle and crust for the backgrounds, the surfaces for borders, green and red for diffs, and the syntax colours OpenCode's theme uses. The two diff background tints, which are not palette colours, sit on `surface0` and `surface1`.

## Turning it off

`nekoshell plugin remove opencode` restores the `theme` key and removes the rendered theme and the shell function; `--purge` also uninstalls OpenCode. `NEKOSHELL_AI_WELCOME=0` keeps everything but the banner.
