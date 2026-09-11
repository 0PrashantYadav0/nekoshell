# Changelog

## 0.1.0 (unreleased)

- Catppuccin look: iTerm2 theme, Starship prompt, themed bat and btop, JetBrainsMono Nerd Font.
- All four Catppuccin flavours, switched with one command: `nekoshell-theme latte` re-renders the iTerm2 profiles, the Starship prompt, the greeting, bat, fzf, delta and btop. Mocha stays the default. Every colour comes from `data/palettes.json`, generated from the Catppuccin palette repository at a pinned commit, and `nekoshell-doctor` reports the flavour in force.
- Greeting on new interactive terminals: Pokémon colourscripts or your own art pack, plus machine stats from fastfetch, under a 150 ms budget.
- Greeting stats now include storage, battery, Wi-Fi and IP address alongside OS, host, uptime, shell, terminal, CPU, memory and packages.
- Two-line Starship prompt: full working directory, git and language status on top, with duration, exit status and the clock right-aligned; the character prompt on its own line below.
- Pokémon facts line in the greeting: national dex number, type and generation next to the name, from a generated PokéAPI data table.
- Spotify panel: a hotkey-toggled iTerm2 window running spotify_player, with a shpotify remote fallback for non-Premium accounts.
- Idempotent installer with automatic backups, a `nekoshell-doctor` check, and a matching uninstaller.
- Agent install contract (`AGENTS.md`) and a skill for installing nekoshell unattended.

### Verified on real hardware

Installed on macOS 26.5.2 (Tahoe), Apple M1, 8 GB, zsh 5.9, iTerm2 3.7.0, Homebrew 6.0.22.
`nekoshell-doctor` reports 14 ok, 2 warn, 0 fail; the greeting measures 85-88 ms against
its 150 ms budget. The `theme` row was added after that run, so a current install reports one
more ok. The two warnings are the expected ones: iTerm2 global preferences are
pending (iTerm2 was running) and Spotify is not authenticated yet.

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
