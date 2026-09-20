# claude-code

## What you get

Claude Code in the flavour: a Catppuccin custom theme (brand accent in mauve, plan mode in sapphire, accept-edits in green, errors in red, message backgrounds on the surface colours), a status line with the model, directory, branch and context use, and the [ai](ai.md) plugin's welcome banner before every interactive session. A `nekoshell theme` switch re-renders both and Claude Code picks the theme up without a restart.

## Using it

| Command | What it does |
| --- | --- |
| `claude` | the banner, then Claude Code |
| `claude -p "..."`, `claude --version`, `claude mcp ...` | untouched: no banner for non-interactive uses and subcommands |
| `command claude` | skip the wrapper entirely |
| `/theme` inside Claude Code | shows "nekoshell Mocha" (or the flavour) selected; pick another to leave the plugin's theme |
| `nekoshell doctor --plugin claude-code` | the binary, the theme and the status line |

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.claude/themes/nekoshell.json` | rendered on add and on every theme switch | no: edit `plugins/claude-code/files/theme.json.tmpl` |
| `~/.config/nekoshell/ai/claude-statusline.sh` | rendered on add and on every theme switch | no: edit `plugins/claude-code/files/statusline.sh.tmpl` |
| `~/.claude/settings.json` | two keys touched in place: `theme` and `statusLine`; the previous values are kept in `~/.config/nekoshell/ai/claude-previous.json` and restored on removal | yes, everything else in it |

## Theme

The template maps Claude Code's colour tokens onto palette roles: `claude` (the accent) to mauve, `text` to text, `inactive` and `subtle` to the overlay and surface greys, `success`, `error`, `warning` to green, red, yellow, `planMode` to sapphire, `autoAccept` to green, `bashBorder` to pink, the message backgrounds to the surfaces. The base preset is `light` for latte and `dark` for the other flavours, so anything the template does not name follows the right side.

## Turning it off

`nekoshell plugin remove claude-code` puts `theme` and `statusLine` back to what they were, removes the two rendered files and the shell function. `NEKOSHELL_AI_WELCOME=0` keeps everything but the banner.
