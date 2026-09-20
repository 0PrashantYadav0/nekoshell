# ai

## What you get

A welcome banner in front of every AI coding tool the tool plugins wrap ([claude-code](claude-code.md), [opencode](opencode.md)): which tool, which project and branch you are in, the last commit and how long ago. Outside a git repository it names the directory instead. The values are drawn in the flavour's accent colour, the rest of the text in a muted one.

```text
Welcome to Claude Code. You are in nekoshell on main.
Last commit 5832ced "Merge pull request #5" 2 hours ago.
```

## Using it

| Command | What it does |
| --- | --- |
| `nekoshell ai welcome [TOOL]` | print the banner as that tool would see it (default `claude-code`) |
| `nekoshell ai edit` | open the template in `$EDITOR` |
| `nekoshell ai status` | the tool plugins: enabled or not, where the binary is, which template applies |
| `NEKOSHELL_AI_WELCOME=0 claude` | no banner this once; export it to switch the banner off |

Placeholders the templates understand:

| Placeholder | Value |
| --- | --- |
| `@@TOOL@@` | Claude Code, OpenCode |
| `@@PROJECT@@` | the repository's directory name |
| `@@BRANCH@@` | the current branch, or `detached at <hash>` |
| `@@COMMIT@@`, `@@SUBJECT@@`, `@@WHEN@@` | the last commit's short hash, subject and relative date |
| `@@DIR@@` | the current directory, with `~` for your home (used outside a repository) |

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.config/nekoshell/ai/welcome.txt` | copied once | yes; it is the banner inside a repository |
| `~/.config/nekoshell/ai/welcome-norepo.txt` | copied once | yes; the banner outside one |
| `~/.config/nekoshell/ai/welcome.TOOL.txt` | yours, optional | yes; wins over the shared one for that tool |
| `~/.config/nekoshell/ai/colors.sh` | rendered on add and on every theme switch | no |

## Theme

Two colours, the flavour's mauve for the values and its subtext for the sentence, rendered on every `nekoshell theme <flavour>`.

## Turning it off

`NEKOSHELL_AI_WELCOME=0` in `~/.config/nekoshell/zsh/local.zsh` keeps the plugins and silences the banner. `nekoshell plugin remove ai` removes the command and the banner program once the tool plugins are removed; the templates stay.
