# vscode

## What you get

Ctrl+Shift+C and the Explorer's "Open in External Terminal" open the nekoshell terminal (kitty, Ghostty, iTerm2, Warp or Terminal.app) in the project folder. The Explorer's right-click shows both "Open in Integrated Terminal" and "Open in External Terminal".

## Using it

| Command | What it does |
| --- | --- |
| `nekoshell plugin add vscode` | sets `terminal.external.osxExec` to the app for the `terminal` id in `nekoshell.toml`, and `terminal.explorerKind` to `both` |
| `nekoshell vscode terminal` | prints the app in use and its nekoshell id, for example `kitty.app (kitty)`, or `not set` |
| `nekoshell vscode terminal ghostty` | changes it: an id from the table below, or `Something.app` for a terminal nekoshell has no adapter for |
| `nekoshell doctor --plugin vscode` | VS Code itself, the external terminal in use and whether the debug console can open it |

The id and the app it maps to:

| id | App |
| --- | --- |
| `kitty` | `kitty.app` |
| `ghostty` | `Ghostty.app` |
| `iterm2` | `iTerm.app` |
| `warp` | `Warp.app` |
| `terminal-app` | `Terminal.app` |

Two limits.

The debug console. `"console": "externalTerminal"` in `launch.json` is handled by VS Code's own scripts, not by this plugin, and only works with `Terminal.app`, `iTerm.app` and `Ghostty.app`. With kitty or Warp set, VS Code reports `'kitty.app' not supported`; use `integratedTerminal` there instead, or set the external terminal to one of the three.

The panel inside the window. VS Code's integrated terminal is its own renderer; it cannot be replaced by kitty, Ghostty or any other emulator, and nekoshell does not try. What can be set by hand, with the exact keys: `terminal.integrated.defaultProfile.osx` (`"zsh"`) and `terminal.integrated.fontFamily` (`"JetBrainsMono Nerd Font"`, the font nekoshell installs), so the prompt and its icons render the same inside VS Code.

`terminal.sourceControlRepositoriesKind` is the same choice for the Source Control view. The plugin leaves it alone.

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/Library/Application Support/Code/User/settings.json` | two keys touched in place: `terminal.external.osxExec` and `terminal.explorerKind`; comments and the other keys stay as they are; `NEKOSHELL_VSCODE_SETTINGS` names another file, for Insiders, VSCodium or Cursor | yes, everything else in it |
| `~/.config/nekoshell/vscode/previous.json` | the two previous values, restored on removal | no |

## Theme

None: the external terminal is themed by its own adapter on `nekoshell theme`.

## Turning it off

`nekoshell plugin remove vscode` restores both keys; nothing else is left behind but `previous.json`.
