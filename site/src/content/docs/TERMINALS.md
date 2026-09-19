# Terminals

Five terminals have an adapter: iTerm2, kitty, Ghostty, Warp and Apple Terminal.app. Every one of them gets the JetBrainsMono Nerd Font, the Catppuccin flavour in force and a way to open the music panel. What differs is inline images, background images and whether a key opens the panel from outside the terminal.

| Terminal | Inline images | Background image | Panel key |
| --- | --- | --- | --- |
| iTerm2 | yes | yes | ⌥M, from any app (hotkey window) |
| kitty | yes | yes, PNG (others converted) | alt+m, inside kitty |
| Ghostty | yes | yes | ⌥M, from any app, after Accessibility is granted |
| Warp | yes | JPEG only | none; `nekoshell music --panel` or the `+` menu opens a new window |
| Terminal.app | no | no | none; `nekoshell music --panel` opens a new window |

## Configuring them

```bash
nekoshell terminal list              # every adapter, installed or not, * for the configured ones
nekoshell terminal detect            # the terminal this shell runs in
nekoshell terminal use kitty,ghostty # configure a named few
nekoshell terminal use all           # every terminal with an adapter
nekoshell terminal use installed     # every terminal whose app is on this Mac
nekoshell terminal remove warp       # take nekoshell's config back out of one
nekoshell terminal apply             # re-render every configured terminal
nekoshell terminal capabilities      # what the terminal this shell runs in can do
nekoshell terminal background ~/Pictures/bg.jpg 0.85
nekoshell terminal background none
```

A machine can configure several terminals at once. A theme switch, the doctor and uninstall walk every configured one; the greeting and the panel always act on the terminal the shell is actually running in, so the window in front of you is the one that changes. `nekoshell terminal background PICTURE [OPACITY]` sets a background on every configured terminal that can draw one and `none` takes it away; the choice is recorded in `nekoshell.toml` and re-applied on every theme switch.

## What each one needs from you

- **iTerm2.** The dynamic profile and the ⌥M hotkey window need nothing. The global preferences (default profile, margins, tab bar, pane dimming) can only be written while iTerm2 is not running, because iTerm2 rewrites that file from memory when it quits: quit it and run `nekoshell terminal apply`. The doctor's `iterm2 prefs` row warns until then.
- **kitty.** Nothing. A new window reads the new config; ctrl+shift+f5 reloads an open one. alt+m opens the panel from inside kitty, and kitty has no global hotkey of its own on macOS.
- **Ghostty.** Grant Accessibility in System Settings, Privacy & Security, Accessibility, or the global ⌥M keybind does nothing, and restart Ghostty once so the quick terminal's position takes effect. Ghostty reloads the rest of its config on ⌘⇧, (comma).
- **Warp.** Sign in; Warp shows nothing until you do. It hot-reloads its settings file, so the theme and the font appear while it runs.
- **Terminal.app.** Quit and reopen it: it reads its profiles and the default profile name once, at launch. 24-bit colour only on macOS 26 and later; before that every colour is rounded to the nearest of 256 and the doctor says so.

## The per-terminal pages

Each adapter's own page says exactly which files it writes, how its panel opens, what happens on removal and what it cannot do:

- [iTerm2](../terminals/iterm2/README.md): a dynamic profile, the global preferences, the shell integration, the hotkey window.
- [kitty](../terminals/kitty/README.md): two rendered config files and one include line, the quick-access terminal, the converted background PNG.
- [Ghostty](../terminals/ghostty/README.md): one rendered config file included from the main one, the quick terminal as the panel.
- [Warp](../terminals/warp/README.md): a custom theme, three keys in `settings.toml`, a tab config for the panel.
- [Terminal.app](../terminals/terminal-app/README.md): a profile installed into the preferences domain, a `.command` file for the panel.

How an adapter is built, function by function, is in [ARCHITECTURE.md](ARCHITECTURE.md); how to write a new one is in the [contributor guides](https://github.com/0PrashantYadav0/nekoshell/blob/main/docs/contributing/writing-a-terminal-adapter.md).
