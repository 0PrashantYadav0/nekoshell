# Changelog

## 0.1.0 (unreleased)

- Catppuccin Mocha look: iTerm2 theme, Starship prompt, themed bat and btop, JetBrainsMono Nerd Font.
- Greeting on new interactive terminals: Pokemon colourscripts or your own art pack, plus machine stats from fastfetch, under a 150 ms budget.
- Spotify panel: a hotkey-toggled iTerm2 window running spotify_player, with a shpotify remote fallback for non-Premium accounts.
- Idempotent installer with automatic backups, an `nekoshell-doctor` health check, and a matching uninstaller.
- Agent install contract (`AGENTS.md`) and a skill for installing nekoshell unattended.

### Verified on real hardware

Installed on macOS 26.5.2 (Tahoe), Apple M1, 8 GB, zsh 5.9, iTerm2 3.7.0, Homebrew 6.0.22.
`nekoshell-doctor` reports 14 ok, 2 warn, 0 fail; the greeting measures 85-88 ms against
its 150 ms budget. The two warnings are the expected ones: iTerm2 global preferences are
pending (iTerm2 was running) and Spotify is not authenticated yet.

Fixed while verifying:

- `Brewfile` no longer taps `homebrew/bundle`. That tap is deprecated and tapping it now
  aborts the whole bundle, taking every package with it.
- `Brewfile` no longer carries `cask "iterm2"`. iTerm2 is a precondition the installer
  already checks for, and the cask collides with an existing `/Applications/iTerm.app`.
- `nekoshell-doctor` reads the greeting's timing line off the end of the line. Real
  Pokemon art ends on a colour reset with no newline, so the line arrives as
  `<ESC>[mgreet: 88 ms` and the old anchored pattern never matched it: every real machine
  reported "could not measure".

The Spotify panel keeps window type 6 ("Right of screen"). Its docking is still unconfirmed
on real hardware: capturing the screen needs Screen Recording permission and creating the
window over AppleScript needs iTerm2's "dangerous commands" prompt answered, neither of
which a script can grant itself. Press ⌥M after restarting iTerm2 to check. If the panel
does not dock to the right edge, re-run the installer with `NEKOSHELL_PANEL_WINDOW_TYPE`
set to 10, 5, 9, 2 or 4 until it does.
