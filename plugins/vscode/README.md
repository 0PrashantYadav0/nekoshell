# vscode

## What it does

Makes Visual Studio Code open the terminal nekoshell is configured for, not
Terminal.app, when you press Ctrl+Shift+C or choose "Open in External
Terminal" from the Explorer. Two keys in VS Code's user settings:

- `terminal.external.osxExec`: the app for the `terminal` id in
  `~/.config/nekoshell/nekoshell.toml`: kitty is `kitty.app`, ghostty
  `Ghostty.app`, iterm2 `iTerm.app`, warp `Warp.app`, terminal-app
  `Terminal.app`. A terminal with no entry gets a warning and no value;
  `nekoshell vscode terminal <id|App.app>` sets one by hand.
- `terminal.explorerKind`: `"both"`, so the Explorer's right-click offers
  "Open in Integrated Terminal" and "Open in External Terminal".

VS Code watches the file, so the change applies without a restart. The
debug console's `"console": "externalTerminal"` is scripted by VS Code
itself and supports only Terminal.app, iTerm.app and Ghostty.app; the doctor
says so for kitty and Warp. The integrated panel inside the window cannot be
another terminal emulator.

## Installs

Nothing from Homebrew. VS Code is not installed by the plugin; the install
hook says `brew install --cask visual-studio-code` when it is missing, and
writes nothing when its settings directory is missing too.

## Files

Touched in place, two keys only: `terminal.external.osxExec` and
`terminal.explorerKind` in
`~/Library/Application Support/Code/User/settings.json`
(`NEKOSHELL_VSCODE_SETTINGS` points at another file, for Insiders, VSCodium
or Cursor). Comments, trailing commas and every other key in the file stay
as they were. The previous values are recorded in
`~/.config/nekoshell/vscode/previous.json` and put back on removal.

## After install

In VS Code, press Ctrl+Shift+C or right-click a folder in the Explorer and
choose "Open in External Terminal": the nekoshell terminal opens in that
folder. `nekoshell doctor --plugin vscode` shows the app in use.

## Remove

`nekoshell plugin remove vscode` restores the two settings; a key that was
absent before is removed again. VS Code stays.
