# Agent install contract for nekoshell

This file is written as instructions to an agent installing nekoshell on a Mac. Follow it in order. Do not skip the precondition checks.

## 1. Preconditions

Run each check command. If any fails, stop and report it; do not try to work around it.

```bash
uname -s               # must print Darwin
command -v brew        # must print a path
ls /Applications/iTerm.app
zsh --version
```

If Homebrew is missing, stop. Hand the human this command; do not run it yourself:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

If iTerm2 is missing, stop. The installer checks for it too and refuses to run without it. Hand the human this command:

```bash
brew install --cask iterm2
```

## 2. Where to run from

Run the installer from a terminal that is not iTerm2: Terminal.app, or the Claude Code desktop app. The installer's last step needs iTerm2 quit so it can write global preferences; running from inside iTerm2 means that step cannot complete.

If you cannot avoid running from iTerm2, run the installer anyway and expect the "iTerm2 global preferences" step to be reported as pending.

## 3. Install

```bash
[ -d ~/.nekoshell ] || git clone https://github.com/0PrashantYadav0/nekoshell.git ~/.nekoshell; cd ~/.nekoshell && git pull --ff-only && ./install.sh --yes
```

Re-running this command is safe; it updates an existing checkout instead of failing on it, and the installer is idempotent. On a machine without Spotify, add `--skip-spotify`.

## 4. Verify

```bash
bin/nekoshell-doctor --json
```

Success is exit code 0. Only `fail` rows block that; `warn` rows do not. On a fresh machine, expect `warn` on these checks, and report them to the human rather than trying to fix them yourself:

- `spotify`: the human still needs to log in.
- `iterm2 prefs`: iTerm2 needs to be quit for this to apply.
- `greet time`: the greeting took longer than its 150 ms budget, or could not be measured. Report the number; do not block on it.

The `theme` row is not one of them: a finished install reports `ok` with the flavour in force. If it warns, the theme was never rendered; `nekoshell-theme mocha` fixes it.

Any `fail` row means the install is not done. Read that row's detail, fix the underlying problem, and re-run the doctor. Do not proceed to step 5 with a `fail` row present.

## 5. Hand off to the human

Give the human these steps verbatim, then stop:

1. Quit and reopen iTerm2.
2. If the doctor reported `iterm2 prefs` as pending, quit iTerm2 and, from Terminal.app, run:
   ```bash
   ~/.nekoshell/install.sh --iterm-prefs
   ```
3. Run `spotify_player authenticate` (opens a browser; requires Spotify Premium).
4. Press ⌥M to open the panel.
5. Run `tmux` and press `C-a I` once. This installs the tmux plugins, including the Catppuccin status bar. Only a human can do it: the binding runs inside a tmux session. Do not start a tmux session yourself to do it for them.

## 6. What changed, and how to undo it

The installer backs up every file it replaces before touching anything. Backups live at:

```
~/.local/share/nekoshell/backup/<timestamp>/
```

Each backup directory has a `manifest.txt` listing every path it holds, relative to `$HOME`. Never delete this directory.

To roll the installer back:

```bash
./uninstall.sh --yes
```

This unstows the linked configs, restores the most recent backup, and removes the iTerm2 profiles.

It does not undo everything. It deliberately leaves behind:

- the `[include]` line it added to `~/.gitconfig`
- `~/.local/bin/pokemon-colorscripts` and its clone in `~/.local/share/pokemon-colorscripts`
- your own files in `~/.config/nekoshell/`: `zsh/local.zsh`, `greet.conf`, `art/`, `theme` and `theme.zsh`
- `~/.config/nvim/` and `~/.config/tmux/`, which are yours once the first install has copied them there, and the tmux plugin manager in `~/.tmux/plugins/`
- `~/.config/starship.toml` and `~/.config/fastfetch/config.jsonc` when there was no earlier file of yours to restore over them, and the `color_theme` line it set in `~/.config/btop/btop.conf`
- the cache in `~/.cache/nekoshell`
- the five other iTerm2 defaults it wrote: `HideTab`, `TerminalMargin`, `TerminalVMargin`, `PromptOnQuit`, `HideScrollbar`
- Homebrew packages

It prints the commands for the last two so you can finish by hand if you want to.

## 7. Rules

- These files belong to the user. The installer writes each one once and then leaves it alone: `~/.config/nekoshell/zsh/local.zsh`, `~/.config/nekoshell/greet.conf`, `~/.config/nekoshell/art/`, `~/.config/starship.toml`, `~/.config/fastfetch/config.jsonc`, `~/.config/nvim/init.lua` with the three files under `~/.config/nvim/lua/nekoshell/`, and `~/.config/tmux/tmux.conf`. Everything else under `~/.config/nekoshell/` is a symlink into the checkout and must not be edited.
- `~/.config/nekoshell/theme`, `~/.config/nekoshell/theme.zsh` and `~/.config/tmux/nekoshell-theme.conf` are nekoshell's own: the installer rewrites them every run. Change them with `nekoshell-theme <flavour>`, never by hand.
- Do not start a tmux session to finish the install. The plugin install binding is a human step, and a session started from an agent's shell attaches to the terminal it is running in.
- `nekoshell-theme <flavour>` is the one command that does overwrite `~/.config/starship.toml`, `~/.config/fastfetch/config.jsonc` and `~/.config/nekoshell/theme.zsh`. Only run it when the human asked for a different flavour; say so first if they have edited those files.
- Do not run `defaults write` for iTerm2 while iTerm2 is running; it will be overwritten when iTerm2 quits.
- Do not install pokemon-colorscripts with sudo.
- Do not commit to this repo on the user's behalf.
