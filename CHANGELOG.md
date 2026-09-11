# Changelog

## 0.1.0 (unreleased)

- Catppuccin look: iTerm2 theme, Starship prompt, themed bat and btop, JetBrainsMono Nerd Font.
- All four Catppuccin flavours, switched with one command: `nekoshell-theme latte` re-renders the iTerm2 profiles, the Starship prompt, the greeting, bat, fzf, delta and btop. Mocha stays the default. Every colour comes from `data/palettes.json`, generated from the Catppuccin palette repository at a pinned commit, and `nekoshell-doctor` reports the flavour in force.
- Greeting on new interactive terminals: Pokémon colourscripts or your own art pack, plus machine stats from fastfetch, under a 150 ms budget.
- Greeting stats now include storage, battery, Wi-Fi and IP address alongside OS, host, uptime, shell, terminal, CPU, memory and packages.
- Two-line Starship prompt: full working directory, git and language status on top, with duration, exit status and the clock right-aligned; the character prompt on its own line below.
- Pokémon facts line in the greeting: national dex number, type and generation next to the name, from a generated PokéAPI data table.
- Spotify panel: a hotkey-toggled iTerm2 window running spotify_player, with a shpotify remote fallback for non-Premium accounts.
- fzf previews on every binding: Ctrl-T through bat, Alt-C as an eza tree, Ctrl-R wrapped so a long history line is readable, and an eza listing beside `cd` completions. `fd` supplies the file list when it is installed.
- Command line syntax highlighting in the flavour's colours, and autosuggestions in its dimmest readable grey. The theme files are vendored from catppuccin/zsh-syntax-highlighting at a pinned commit and loaded from `theme.zsh`, above the antidote block, because the plugin reads its styles at load time.
- atuin on Ctrl-R: shell history in a searchable local database, with sync and the update check off and the up arrow left on plain zsh history. `nekoshell-doctor` reports it as a tool.
- An iTerm2 status bar on the main profile: working directory and git branch on the left, CPU, memory, battery and the clock on the right, coloured from the flavour. The installer downloads iTerm2's shell integration, which the first two components read, and the uninstaller leaves that file in place.
- The cursor guide is on, and inactive split panes are dimmed.
- The installer and `nekoshell-theme` run `bat cache --build`. bat reads themes out of its own cache rather than out of `~/.config/bat/themes`, so the vendored Catppuccin themes were invisible until now. `nekoshell-doctor` has a `bat theme` row that warns when the cache is stale.
- Neovim, themed with the rest of the rig: a config in `~/.config/nvim/` with lazy.nvim, catppuccin following `$NEKOSHELL_THEME`, treesitter, telescope, oil, lualine, gitsigns, which-key, indent guides, autopairs and comments, on a Space leader. `vim` and `vi` reach it and `EDITOR` prefers it, both only when it is installed.
- tmux, themed with the rest of the rig: `C-a` as the prefix, `|` and `-` for splits, `hjkl` to move and resize panes, a mouse, and a Catppuccin status bar on top. `t` starts or attaches to a session called main. The installer clones the tmux plugin manager at a pinned commit; the plugins themselves arrive when you press `C-a I` once inside tmux. `nekoshell-theme` writes the flavour into `~/.config/tmux/nekoshell-theme.conf`, which the config sources, so a switch never edits a file that is yours.
- Both configs are yours the moment they land: copied once on the first install, never stowed, never overwritten. A config you already have is left completely alone and nothing is replaced, so nothing is backed up either: an `init.lua` or `init.vim` under `~/.config/nvim` stops the Neovim copy, and a `~/.tmux.conf` or `~/.config/tmux/tmux.conf` stops the tmux one. The installer warns and points at `templates/`.
- Idempotent installer with automatic backups, a `nekoshell-doctor` check, and a matching uninstaller.
- Agent install contract (`AGENTS.md`) and a skill for installing nekoshell unattended.

### Verified on real hardware

Installed on macOS 26.5.2 (Tahoe), Apple M1, 8 GB, zsh 5.9, iTerm2 3.7.0, Homebrew 6.0.22.
`nekoshell-doctor` reports 14 ok, 2 warn, 0 fail; the greeting measures 85-88 ms against
its 150 ms budget. The `theme` row was added after that run, so a current install reports one
more ok. The two warnings are the expected ones: iTerm2 global preferences are
pending (iTerm2 was running) and Spotify is not authenticated yet.

Five rows were added after that run: `theme`, `tool: atuin`, `bat theme`, `tool: nvim` and
`tool: tmux`. On a machine installed before those packages joined the Brewfile, each reports
fail until `brew bundle --file Brewfile` installs them, after which it moves to ok. `bat theme`
reports ok once the installer or `nekoshell-theme` has run `bat cache --build`, and warns
otherwise.

The Neovim and tmux configs are not verified on real hardware yet. Neither tool was installed
on the machine that ran the test suite, so the tests that ask `luac` or `tmux` to parse the
shipped files skipped rather than ran. Everything else about them is covered: the copy, the
backup, the flavour file, the plugin manager clone, the aliases and `EDITOR`.

Fixed while verifying:

- `Brewfile` no longer taps `homebrew/bundle`. That tap is deprecated and tapping it now
  aborts the whole bundle, taking every package with it.
- `Brewfile` no longer carries `cask "iterm2"`, because the cask collides with an existing
  `/Applications/iTerm.app`. iTerm2 is a precondition instead, and the installer's preflight
  now checks for it and stops with `brew install --cask iterm2` if it is missing.
- `nekoshell-doctor` reads the greeting's timing line off the end of the line. Real
  Pokémon art ends on a colour reset with no newline, so the line arrives as
  `<ESC>[mgreet: 88 ms` and the old anchored pattern never matched it: every real machine
  reported "could not measure".

The Spotify panel keeps window type 6 ("Right of screen"). Its docking is still unconfirmed
on real hardware: capturing the screen needs Screen Recording permission and creating the
window over AppleScript needs iTerm2's "dangerous commands" prompt answered, neither of
which a script can grant itself. Press ⌥M after restarting iTerm2 to check. If the panel
does not dock to the right edge, re-run the installer with `NEKOSHELL_PANEL_WINDOW_TYPE`
set to 10, 5, 9, 2 or 4 until it does.
