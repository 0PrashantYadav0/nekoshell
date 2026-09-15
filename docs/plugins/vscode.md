# vscode

## What you get

Visual Studio Code opens the terminal nekoshell is configured for, instead of Terminal.app, when you press Ctrl+Shift+C or choose "Open in External Terminal" in the Explorer, and the Explorer's right-click offers both "Open in Integrated Terminal" and "Open in External Terminal". The debug console's `"console": "externalTerminal"` is VS Code's own and works only with Terminal.app, iTerm.app and Ghostty.app; the integrated panel inside the window stays VS Code's.

## Using it

| Command | What it does |
| --- | --- |
| `nekoshell plugin add vscode` | sets `terminal.external.osxExec` to the app for the `terminal` id in `nekoshell.toml` (kitty.app, Ghostty.app, iTerm.app, Warp.app or Terminal.app) and `terminal.explorerKind` to `both` |
| `nekoshell doctor --plugin vscode` | VS Code, the app the external terminal opens, and whether the debug console can use it |

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/Library/Application Support/Code/User/settings.json` | two keys touched in place: `terminal.external.osxExec` and `terminal.explorerKind`; comments and the other keys stay as they are; `NEKOSHELL_VSCODE_SETTINGS` names another file (Insiders, VSCodium, Cursor) | yes, everything else in it |
| `~/.config/nekoshell/vscode/previous.json` | the two previous values, restored on removal | no |

## Theme

Nothing: the plugin changes which terminal opens, and that terminal carries the flavour.

## Turning it off

`nekoshell plugin remove vscode` puts both keys back to what they were; a key that was absent before is removed again. VS Code stays.
