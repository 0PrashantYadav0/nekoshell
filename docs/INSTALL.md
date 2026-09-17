# Install

The human version of the install steps. For an AI agent, see [AGENTS.md](https://github.com/0PrashantYadav0/nekoshell/blob/main/AGENTS.md) in the repository (it does not ship in the release tarball).

## 1. Before you start

nekoshell runs on macOS only and needs Homebrew, zsh and git. `install.sh` checks for macOS and Homebrew and stops with the Homebrew install line if it is missing.

The installer puts Starship, antidote and the JetBrainsMono Nerd Font in through Homebrew during step four, only for whichever is missing. `nekoshell doctor` reports each one afterwards: `starship` fails when the prompt is absent, `zsh plugin manager` warns when antidote is, and `font` warns when the cask is, with the command to run.

Install the terminal you want before running the installer, so it can be detected and configured. iTerm2, kitty, Ghostty and Warp are all Homebrew casks; Terminal.app is already there.

## 2. Clone and run the installer

### The one-line installer

```bash
curl -fsSL https://raw.githubusercontent.com/0PrashantYadav0/nekoshell/main/bootstrap.sh | bash
```

It clones `~/.nekoshell` (or updates it), then runs `install.sh` with any flags you pass after `bash -s --`, so the non-interactive form is:

```bash
curl -fsSL https://raw.githubusercontent.com/0PrashantYadav0/nekoshell/main/bootstrap.sh | bash -s -- --yes --profile full --terminal installed
```

`NEKOSHELL_REF=v0.2.0` in front of the line pins a release instead of `main`; `NEKOSHELL_DIR` moves the checkout. The clone is shallow (`--depth 1`): it gets the tree at that ref, not the project's history, which is what an install needs and keeps the download small. A contributor who wants the log, `git blame` or an older commit should clone by hand instead, the way the section below does.

```bash
git clone https://github.com/0PrashantYadav0/nekoshell.git ~/.nekoshell
cd ~/.nekoshell
./install.sh
```

`install.sh` hands over to `nekoshell install`, which runs seven steps:

1. **Terminal.** The terminal this shell runs in, when it has an adapter. Otherwise the installer lists the installed terminals and asks. `--terminal ID`, `--terminal a,b`, `--terminal all` (every adapter) or `--terminal installed` (every app that is present) answers it without asking.
2. **Profile.** `minimal` (modern-cli, greet, pokemon), `dev` (adds fzf, atuin, lazygit, btop, nvim, tmux), `full` (adds spotify) or `pick`, a menu that toggles plugins one by one. `--profile P` answers it; `--with a,b` and `--without c` adjust the list. With `--yes` and no `--profile`, `minimal` is used.
3. **Confirm.** Skipped with `--yes` or `--check`.
4. **Backup and core.** Aliases in an existing `~/.zshrc` are moved to `~/.config/nekoshell/zsh/local.zsh`, the old file goes into the backup set, nekoshell's zshrc is linked in its place, and `~/.config/nekoshell/nekoshell.toml` is written.
5. **Theme.** The Starship config and the shell colours are rendered for the recorded flavour (mocha the first time), then every configured terminal.
6. **Plugins.** Each plugin in the profile is enabled: its Homebrew formulas and casks, its linked and copied files, its install and theme hooks.
7. **Doctor and next steps.** The doctor runs, then the "After install" section of every enabled plugin's README is printed.

Every file the installer replaces is moved into `~/.local/share/nekoshell/backup/<timestamp>/` first, with a `manifest.txt` beside it. Running `./install.sh` again is safe: it links nothing twice and backs up nothing it wrote itself.

`./install.sh --check` prints what would change and changes nothing. `--dry-run` does the same without skipping the confirmation.

## 3. Steps only you can do

The installer prints the ones that apply. By terminal:

- **iTerm2.** If iTerm2 was running during the install, its global preferences (default profile, margins, tab bar, pane dimming) could not be written: iTerm2 rewrites that file from memory when it quits. Quit iTerm2, then run `nekoshell terminal apply`. The doctor's `iterm2 prefs` row warns until this is done. The dynamic profiles and the ⌥M hotkey window need nothing: iTerm2 picks them up by itself.
- **kitty.** Nothing. New windows read the new config; press ctrl+shift+f5 in an open one. alt+m opens the music panel from inside kitty.
- **Ghostty.** Grant Accessibility (System Settings, Privacy & Security, Accessibility), or the global ⌥M keybind does nothing. Restart Ghostty once: it reloads most of its config on ⌘⇧, (comma), but the quick terminal's position only on a restart.
- **Warp.** Sign in to Warp. It hot-reloads its settings file, so the theme and font show as soon as it is running.
- **Terminal.app.** Quit and reopen Terminal.app. It reads its profiles and the default profile name once, at launch, so windows opened before then keep the old profile. The doctor's `terminal-app default` row says so until you do.

By plugin, when enabled:

- **spotify.** Run `nekoshell spotify login`; it opens a browser and needs a Spotify Premium account. Register a Spotify app of your own and run `nekoshell spotify client-id <id>`, or start-up waits on Spotify's rate limit for the shared id. Without spotify_player the player becomes a keyboard remote for the desktop app.
- **tmux.** Start `tmux` and press `C-a I` once. TPM then fetches the plugins, including the Catppuccin status line.
- **nvim.** Open `nvim` once; lazy.nvim fetches its plugins on the first start.
- **aerospace.** Not in any profile. If you add it, open AeroSpace once and grant it Accessibility.
- **p10k, omz.** Not in any profile either. p10k replaces Starship with Powerlevel10k on the next shell; omz makes the first new shell wait a few seconds while antidote clones oh-my-zsh.

Then open a new terminal window: the prompt, the greeting and the shell colours are read when a shell starts.

## 4. Check

```bash
nekoshell doctor
```

One line per check. `ok` and `warn` rows are fine; the command exits 1 only when a row says `fail`, and each `fail` row names the command that fixes it. `nekoshell doctor --json` prints the same rows as JSON; `--plugin NAME` checks one plugin.

## 5. Themes

```bash
nekoshell theme list      # frappe, latte, macchiato, mocha
nekoshell theme latte     # switch everything
nekoshell theme current   # the flavour in force
nekoshell theme auto      # follow the macOS appearance
```

A switch re-renders `~/.config/starship.toml`, `~/.config/nekoshell/theme.zsh` (bat, fzf, syntax highlighting, autosuggestions), every configured terminal and every enabled plugin's themed files (the fastfetch config, btop's `color_theme`, the tmux flavour file). `auto` renders mocha when macOS is dark and latte when it is light; set `theme_auto_dark` and `theme_auto_light` in `nekoshell.toml` to change the pair. Each new interactive shell runs `nekoshell theme --resolve` in the background, so the switch follows the appearance without a command.

iTerm2, kitty and Warp pick up the new colours by themselves or in the next window; Ghostty needs ⌘⇧, (comma) or a restart; Terminal.app re-reads the profile at launch. The prompt and greeting want a new shell.

## 6. Terminals

```bash
nekoshell terminal list           # every adapter, installed or not, * for the configured ones
nekoshell terminal use ghostty    # configure one more terminal
nekoshell terminal use all        # every terminal with an adapter
nekoshell terminal use installed  # every terminal whose app is on this Mac
nekoshell terminal remove warp    # take nekoshell's config back out of one
nekoshell terminal apply          # re-render every configured terminal
nekoshell terminal background ~/Pictures/bg.jpg 0.85
nekoshell terminal background none
```

A machine can configure several terminals. `nekoshell music` runs the player in the current window; `nekoshell music --panel` opens the running terminal's panel. The greeting and the panel always act on the terminal the shell is running in; the theme, the doctor and uninstall walk every configured one. What each adapter writes, how its panel opens and what it cannot do is in `terminals/<id>/README.md`.

## 7. Plugins

```bash
nekoshell plugin list
nekoshell plugin info tmux
nekoshell plugin add aerospace
nekoshell plugin remove --purge btop   # --purge also uninstalls formulas no other plugin needs
```

Twenty-three plugins ship: modern-cli, greet and its art providers pokemon, anime, minecraft and colorscripts, fzf, atuin, lazygit, btop, nvim, tmux, yazi, gh, mise, spotify, ai, claude-code, opencode, aerospace, p10k, pure and omz. Each plugin's README (`nekoshell plugin info NAME` prints it) says what it installs, which files it links or copies, and what removing it leaves behind. [docs/plugins/README.md](plugins/README.md) is the manual: what each one does day to day, its keys, commands and aliases, the files you may edit, how it follows the theme, and how to turn it off.

## Upgrading

```bash
cd ~/.nekoshell
git pull --ff-only
./install.sh
```

### With Homebrew

`brew upgrade nekoshell`, then open a new shell. nekoshell records `$(brew --prefix)/opt/nekoshell/libexec` as its root rather than the versioned Cellar directory, so the links in your home keep resolving after the upgrade. `nekoshell doctor` confirms it with the `config` row.

A second install asks the terminal and profile again (pass `--terminal` and `--profile`, or `--yes`, to skip that), keeps the recorded theme and every plugin already enabled, and re-renders everything from the new checkout. Configs that were copied into your home (Neovim, tmux, greet.conf, AeroSpace) are yours and are not touched; the shipped versions stay readable under `plugins/<name>/files/copy/`.

### Coming from v0.1

A machine installed by nekoshell v0.1 has `~/.config/nekoshell/theme` and a set of symlinks into a directory this version no longer has. The installer recognises the marker, keeps the recorded flavour, and, when no `--profile` is given, uses `full` so that every config v0.1 had in place stays in use. It then sweeps the twelve paths v0.1 linked (the atuin, lazygit, spotify-player, bat and btop configs, the delta gitconfig and the old zsh files), removing each link that is broken or still points into the checkout's old tree, and drops the old `~/.zshrc` link rather than backing it up. A link of your own that resolves to a real file is left alone. The five v0.1 command names still work as three-line shims onto the matching subcommands.

## Uninstall

```bash
cd ~/.nekoshell
./uninstall.sh          # asks first; --yes skips the question
./uninstall.sh --purge  # also uninstalls the formulas no other plugin needs
```

It removes every enabled plugin in reverse order (their linked files and install-hook changes, such as the delta include in `~/.gitconfig`), unlinks the zshrc, restores every backup set newest first, deletes the Starship config it rendered, takes nekoshell's config back out of every configured terminal, and deletes `theme.zsh`, `antidote.txt` and `nekoshell.toml`.

Left in place, on purpose: `~/.config/nekoshell/zsh/local.zsh`, `greet.conf` and the art pack, `~/.config/fastfetch/config.jsonc`, `~/.config/tmux/nekoshell-theme.conf`, `~/.config/btop/btop.conf`, every config a plugin copied into your home (Neovim, tmux, AeroSpace), the art packs under `~/.local/share` (pokemon-colorscripts with its `~/.local/bin` link, fastfetch-pngs, minecraft-colorscripts, colorscripts), the TPM clone, the backup directory, `~/.iterm2_shell_integration.zsh`, and the Homebrew packages unless you passed `--purge`. iTerm2's global preferences are the one thing an uninstall cannot undo while iTerm2 runs; it prints the `defaults delete` line to run with iTerm2 quit.

## Troubleshooting

Start with `nekoshell doctor`. Every row that is not `ok` names the check and, when there is one, the command that fixes it.

**Icons show as boxes.** The `font` row says the Nerd Font is not installed, or the terminal's own `font` row says the terminal is not using it. Install the cask and run `nekoshell terminal apply`.

**No prompt, no colours, plain zsh.** The `zshrc` row fails when `~/.zshrc` is not nekoshell's link (run `nekoshell install`), the `starship` row when Starship is missing, and the `antidote` row when no plugin has been enabled yet. A missing antidote package gives no row at all: the zshrc skips the plugin block quietly, so `brew install antidote` and open a new shell.

**No greeting.** `nekoshell greet` prints it on demand and shows any error. It is silent on purpose inside tmux, inside the panel, over SSH (unless `NEKOSHELL_GREET_SSH=1`), when stdout is not a terminal, and under Claude Code. The `greet time` row warns when the greeting takes longer than 150 ms.

**The panel does not open.** iTerm2: the hotkey window is in the dynamic profile; the `iterm2 profiles` row says whether it is there, and `nekoshell terminal apply` rewrites it. Ghostty: the `ghostty hotkey` row stays a warning until Accessibility is granted, which the doctor cannot see. kitty: alt+m works from inside a kitty window only. Warp and Terminal.app have no key; `nekoshell music --panel` opens a window there, and `nekoshell music` on its own runs the player in the current window everywhere.

**A terminal shows the old colours.** iTerm2 re-reads its dynamic profile within seconds. kitty needs a new window or ctrl+shift+f5. Ghostty needs ⌘⇧, (comma) or a restart. Warp watches its theme directory but can take a while to notice a new one; restart it. Terminal.app reads profiles at launch; quit and reopen it.

**tmux ignores the theme.** The status line is a tmux plugin, fetched by `C-a I` inside a session. After a theme switch, press `C-a r` or start a new session.

**Neovim has no plugins.** The first `nvim` clones lazy.nvim and the plugins, which needs the network. Quit and start it again when it finishes.

**Spotify does not play.** The `spotify login` row warns until `nekoshell spotify login` (or `spotify_player authenticate`) has run. Without Premium, `nekoshell-spotify --remote` drives the desktop app instead. A window that sits empty for the first 12 to 14 seconds is Spotify rate-limiting spotify_player's shared client id: the `spotify client id` row warns until `nekoshell spotify client-id <id>` has given it one of your own.
