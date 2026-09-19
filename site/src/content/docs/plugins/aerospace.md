# aerospace

## What you get

AeroSpace tiles macOS windows the way i3 does: windows arrange themselves, `alt` plus a letter moves the focus, `alt` plus a number moves between workspaces. The shipped config starts it at login, tiles by default with 8-pixel gaps, and floats the nekoshell panel window (iTerm2's hotkey window, titled `nekoshell panel`) rather than tiling it. `alt-m` is deliberately unbound: it belongs to the terminal's music panel.

AeroSpace needs the Accessibility permission. Open it once and grant it in System Settings, Privacy & Security, Accessibility; nothing tiles until you do. `nekoshell doctor` shows the `aerospace` row as a warning, never a failure, until AeroSpace answers.

## Using it

| Key | Does |
| --- | --- |
| `alt-enter` | open a new iTerm2 window (`open -na iTerm`) |
| `alt-h`, `j`, `k`, `l` | focus left, down, up, right |
| `alt-shift-h`, `j`, `k`, `l` | move the window left, down, up, right |
| `alt-1` to `alt-5` | go to workspace 1 to 5 |
| `alt-shift-1` to `alt-shift-5` | move the window to workspace 1 to 5 |
| `alt-tab` | back to the previous workspace |
| `alt-f` | fullscreen |
| `alt-slash` | tiles layout, toggling horizontal and vertical |
| `alt-comma` | accordion layout, toggling horizontal and vertical |
| `alt-minus`, `alt-equal` | resize by 50 |
| `alt-shift-semicolon` | service mode |

In service mode: `esc` reloads the config and returns to main, `r` flattens the workspace tree, `f` toggles floating and tiling, `backspace` closes every window but the current one.

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.config/aerospace/aerospace.toml` | copied once | yes |

If the file exists already, nothing is copied and the add says so; the shipped one stays at `plugins/aerospace/files/copy/.config/aerospace/aerospace.toml`.

## Theme

None. Nothing in the config carries a colour and the plugin has no theme hook.

## Turning it off

`nekoshell plugin remove aerospace` drops it from the enabled list; the config stays and the app keeps running until you quit it. `--purge` also uninstalls the AeroSpace cask, as long as no other enabled plugin lists it.
