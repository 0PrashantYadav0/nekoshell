# Install

This is the human version of the install steps. For an AI agent, see [AGENTS.md](../AGENTS.md).

## 0. Install iTerm2 first

nekoshell themes iTerm2, so iTerm2 has to be there before you start. The installer checks for it and stops if it is missing.

```bash
brew install --cask iterm2
```

## 1. Clone and run the installer

```bash
git clone https://github.com/0PrashantYadav0/nekoshell.git ~/.nekoshell
cd ~/.nekoshell
./install.sh
```

Run this from Terminal.app, not from iTerm2. The last installer step writes iTerm2's global preferences, and iTerm2 rewrites those preferences itself when it quits. If iTerm2 is running while `install.sh` writes them, iTerm2 will overwrite the change on its next quit. Running from Terminal.app lets the installer check whether iTerm2 is running and skip that step cleanly instead of writing a value that gets lost.

The installer asks for confirmation, then runs ten steps: it installs Homebrew packages, backs up any files it is about to replace, migrates aliases out of your old `.zshrc`, links its own configs with `stow`, records where you cloned it, installs pokemon-colorscripts, adds a git-delta include to `~/.gitconfig`, writes two iTerm2 profiles, and applies iTerm2's global preferences.

Re-running `./install.sh` is safe at any time. Use `install.sh --check` to see what it would change without changing anything, and `install.sh --skip-spotify` if this machine has no Spotify account.

The installer records where you cloned it and writes that path into the iTerm2 panel profile. If you move the checkout, re-run `./install.sh` from its new location.

Your greeting settings are copied to `~/.config/nekoshell/greet.conf` on the first install. That file is yours: later installs leave it alone.

## 2. Steps only you can do

The installer prints these at the end. Do them in order:

1. **Quit and reopen iTerm2.** This loads the new profile and the global preferences.
2. **If prompted, run `install.sh --iterm-prefs`.** If iTerm2 was open during install, the installer could not write its global preferences and told you so. Quit iTerm2 first, then from Terminal.app run:
   ```bash
   ~/.nekoshell/install.sh --iterm-prefs
   ```
3. **Run `spotify_player authenticate`.** This opens a browser to log in. It requires a Spotify Premium account; without one, the panel falls back to controlling the Spotify desktop app instead of streaming directly.
4. **Press ⌥M anywhere** to open the Spotify panel.

## 3. Pick the profile by hand (if it did not switch automatically)

1. Open iTerm2 Settings.
2. Go to Profiles.
3. Select **nekoshell**.
4. Click Other Actions, then Set as Default.

## 4. Verify

```bash
nekoshell-doctor
```

This prints one line per check: font, tools, zshrc, iTerm2 profiles and preferences, pokemon-colorscripts, greeting time, and Spotify. It exits 1 if any check fails. Add `--json` for machine-readable output.

## Troubleshooting

**Icons look wrong (boxes or question marks).** The JetBrainsMono Nerd Font is not selected in iTerm2. Open iTerm2 Settings, Profiles, Text, and set the font to a JetBrainsMono Nerd Font variant.

**No greeting appears.** Run `nekoshell-greet` directly to see any error, and `nekoshell-doctor` to check that fastfetch and pokemon-colorscripts are installed. The greeting is also suppressed on purpose inside tmux, over SSH (unless `NEKOSHELL_GREET_SSH=1`), and inside Claude Code.

**Wi-Fi shows `<redacted>` or is missing.** Give iTerm2 Location Services access in System Settings, Privacy and Security, Location Services.

**The panel does not open.** Check iTerm2 Settings, Keys, Hotkey Window. It should show ⌥M bound to the nekoshell panel profile. If the binding is missing, re-run `./install.sh` to rewrite the profiles. `nekoshell-doctor` reports the `iterm2 profiles` row as stale when the profile still points at an old checkout location.

## Uninstall

```bash
./uninstall.sh
```

This unstows the linked configs, restores the files it backed up, and removes the iTerm2 profiles.

It does not undo everything. It deliberately leaves behind:

- the `[include]` line it added to `~/.gitconfig`
- `~/.local/bin/pokemon-colorscripts` and its clone in `~/.local/share/pokemon-colorscripts`
- your own files in `~/.config/nekoshell/`: `zsh/local.zsh`, `greet.conf` and `art/`
- the cache in `~/.cache/nekoshell`
- the five other iTerm2 defaults it wrote: `HideTab`, `TerminalMargin`, `TerminalVMargin`, `PromptOnQuit`, `HideScrollbar`
- Homebrew packages

It prints the commands for the last two so you can finish by hand if you want to.
