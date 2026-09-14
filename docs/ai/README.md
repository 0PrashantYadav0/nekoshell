# nekoshell and AI agents

Two different things, on one page: installing nekoshell through an agent, and the three plugins that dress AI coding tools in the flavour.

## Installing through an agent

[AGENTS.md](../../AGENTS.md) is the contract, and it is what an agent should read. This is the shape of it.

Preconditions, each checked and none worked around: `uname -s` prints `Darwin`, `brew` is on `PATH`, and so are `zsh` and `git`. A missing Homebrew is handed to the human as a line to run, not run by the agent. Starship, antidote and the JetBrainsMono Nerd Font are the installer's own job, so nothing else has to be put there first.

The install is one non-interactive line, from AGENTS.md section 2:

```bash
[ -d ~/.nekoshell ] || git clone https://github.com/0PrashantYadav0/nekoshell.git ~/.nekoshell
cd ~/.nekoshell && git pull --ff-only && ./install.sh --yes --profile full --terminal all
```

`--terminal installed` is the better choice when the human did not name a terminal: it configures only the ones whose app is on the Mac. The line is safe to run again, and `./install.sh --check` prints what would change without changing anything.

Verify with `nekoshell doctor --json`. Exit code 0 is success; the output is a JSON array of `{"status", "check", "detail"}` rows, and only a `fail` row makes the exit code 1. AGENTS.md section 3 lists the `warn` rows that are expected on a fresh machine and which of them are for the human.

Then hand off. AGENTS.md section 4 is the list, in order: iTerm2, Terminal.app, Ghostty's Accessibility grant, signing in to Warp, the Spotify login and client id, `C-a I` inside tmux, and opening `nvim` once. The installer prints the same steps at the end of the run, from each enabled plugin's `## After install` section.

## Claude Code

`skills/nekoshell/SKILL.md` is the skill: AGENTS.md compressed to what an agent needs while it runs. Its frontmatter is what a client matches on:

```yaml
---
name: nekoshell
description: Install the nekoshell terminal rig (Catppuccin look, Pokémon greeting with machine stats, a music panel, five macOS terminals) on a Mac by running its installer and doctor, then handing the human the steps only they can do.
---
```

Point Claude Code at it by putting the `nekoshell` directory where it looks for skills, or by handing it the file. In the checkout it is `skills/nekoshell/SKILL.md`.

Separately, the `claude-code` plugin themes the tool itself. It renders `~/.claude/themes/nekoshell.json` and sets `theme = "custom:nekoshell"` in `~/.claude/settings.json`; it renders a status line at `~/.config/nekoshell/ai/claude-statusline.sh` showing the model, the directory, the branch and the context use, and points `statusLine` at it; and it wraps `claude` in a shell function that prints the welcome banner first. The previous `theme` and `statusLine` values go into `~/.config/nekoshell/ai/claude-previous.json` and are put back on removal. Full page: [../plugins/claude-code.md](../plugins/claude-code.md).

The plugin installs nothing: Claude Code is usually installed by its own installer or through npm, so a Homebrew cask would put a second copy beside it. The install hook only says how when the binary is missing.

## OpenCode

The `opencode` plugin renders `~/.config/opencode/themes/nekoshell.json`, with every one of OpenCode's colour keys on a Catppuccin palette role, and sets `"theme": "nekoshell"` in `~/.config/opencode/tui.json`, recording the previous value in `~/.config/nekoshell/ai/opencode-previous.json`. It wraps `opencode` in a shell function for the banner; `opencode run`, `serve`, `auth`, `upgrade`, `models`, `--version` and `--help` run untouched. Unlike claude-code it does install its tool: `requires = ["opencode"]`. Full page: [../plugins/opencode.md](../plugins/opencode.md).

## The ai plugin

`ai` is what the other two stand on, and both list it in `requires_plugins`. It prints a welcome banner just before an AI tool starts, naming the tool, the project and branch, and the last commit; outside a repository it names the directory instead.

```text
Welcome to Claude Code. You are in nekoshell on main.
Last commit 5832ced "Merge pull request #5" 2 hours ago.
```

The text is yours, in `~/.config/nekoshell/ai/welcome.txt` and `welcome-norepo.txt`, with the placeholders `@@TOOL@@`, `@@PROJECT@@`, `@@BRANCH@@`, `@@COMMIT@@`, `@@SUBJECT@@`, `@@WHEN@@` and `@@DIR@@`. A `welcome.claude-code.txt` beside them wins for that tool.

| Command | What it does |
| --- | --- |
| `nekoshell ai welcome [TOOL]` | print the banner as that tool would see it |
| `nekoshell ai edit` | open the template in `$EDITOR` |
| `nekoshell ai status` | the tool plugins: enabled or not, the binary, the template that applies |

The banner is silent when stdout is not a terminal, and `NEKOSHELL_AI_WELCOME=0` switches it off. It installs nothing from Homebrew. Full page: [../plugins/ai.md](../plugins/ai.md).

## Agents changing this repository

[CLAUDE.md](../../CLAUDE.md) at the root points at [AGENTS.md](../../AGENTS.md), whose "Extending" section is the contract for a plugin, a terminal adapter and the checks. `make check` is what CI runs. Commit messages follow [CONTRIBUTING.md](../../CONTRIBUTING.md), section "Commit messages": a conventional subject, a sign-off, and a `Co-Authored-By: Name <email>` trailer when an assistant wrote the change. Longer walkthroughs are in [../contributing/](../contributing/README.md).

## What an agent must never do

AGENTS.md ends with a "Never" list. Read it there rather than from a copy: editing a rendered file by hand, writing a colour anywhere but `core/theme/palettes.json`, adding a copyrighted image, adding a slow or unpinned art provider, merging a shipped config into one the human already has, running `defaults write` for iTerm2 while it is running, installing anything with sudo, and committing on the human's behalf.

One more, from AGENTS.md section 5: never delete `~/.local/share/nekoshell/backup/`. It is the only copy of the files the installer moved.
