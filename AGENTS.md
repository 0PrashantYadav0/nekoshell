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

## 2. Where to run from

Run the installer from a terminal that is not iTerm2: Terminal.app, or the Claude Code desktop app. The installer's last step needs iTerm2 quit so it can write global preferences; running from inside iTerm2 means that step cannot complete.

If you cannot avoid running from iTerm2, run the installer anyway and expect the "iTerm2 global preferences" step to be reported as pending.

## 3. Install

```bash
git clone https://github.com/0PrashantYadav0/nekoshell.git ~/.local/share/nekoshell && cd ~/.local/share/nekoshell && ./install.sh --yes
```

Re-running this command is safe; the installer is idempotent. On a machine without Spotify, add `--skip-spotify`.

## 4. Verify

```bash
bin/nekoshell-doctor --json
```

Success is exit code 0. Only `fail` rows block that; `warn` rows do not. On a fresh machine, expect `warn` on these checks, and report them to the human rather than trying to fix them yourself:

- `spotify`: the human still needs to log in.
- `iterm2 prefs`: iTerm2 needs to be quit for this to apply.
- `greet time`: the greeting took longer than its 150 ms budget, or could not be measured. Report the number; do not block on it.

Any `fail` row means the install is not done. Read that row's detail, fix the underlying problem, and re-run the doctor. Do not proceed to step 5 with a `fail` row present.

## 5. Hand off to the human

Give the human these steps verbatim, then stop:

1. Quit and reopen iTerm2.
2. If the doctor reported `iterm2 prefs` as pending, quit iTerm2 and, from Terminal.app, run:
   ```bash
   ~/.local/share/nekoshell/install.sh --iterm-prefs
   ```
3. Run `spotify_player authenticate` (opens a browser; requires Spotify Premium).
4. Press ⌥M to open the panel.

## 6. What changed, and how to undo it

The installer backs up every file it replaces before touching anything. Backups live at:

```
~/.local/share/nekoshell/backup/<timestamp>/
```

Each backup directory has a `manifest.txt` listing every path it holds, relative to `$HOME`. Never delete this directory.

To undo everything the installer did:

```bash
./uninstall.sh --yes
```

This unstows the linked configs, restores the most recent backup, and removes the iTerm2 profiles. It does not remove Homebrew packages.

## 7. Rules

- Do not edit files under `~/.config/nekoshell/` except `zsh/local.zsh` and `greet.conf`. Every other file there is a symlink managed by the installer.
- Do not run `defaults write` for iTerm2 while iTerm2 is running; it will be overwritten when iTerm2 quits.
- Do not install pokemon-colorscripts with sudo.
- Do not commit to this repo on the user's behalf.
