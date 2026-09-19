# Apple Terminal.app

## What it configures

Terminal.app keeps every profile inside its preferences (the `com.apple.Terminal` domain, key "Window Settings"), not in a config file. So nekoshell renders a profile named `nekoshell` to `~/.local/share/nekoshell/terminal-app/nekoshell.terminal` from `core/theme/palettes.json` and installs it with `defaults write ... "Window Settings" -dict-add nekoshell`. The profile carries the JetBrainsMono Nerd Font at 15 points (as the PostScript name `JetBrainsMonoNF-Regular`, which is how Terminal archives a font), the sixteen ANSI colours, text, bold, background, cursor and selection colours, a 120x36 window, no bell, and Option as Meta.

`nekoshell terminal apply` then makes `nekoshell` the profile for new windows and for startup ("Default Window Settings" and "Startup Window Settings"). The name that was there before is recorded in `nekoshell.toml` as `terminal_app_previous_default` so removal can put it back. Your own profiles are never edited. The preferences go through `cfprefsd`, so nothing needs Terminal to be closed while it is written; but Terminal reads its profiles and the default profile name once, at launch, so a Terminal that was running during the apply keeps opening windows with the old profile until you quit and reopen it. `nekoshell terminal apply` says so, and the doctor's "terminal-app default" row warns as long as the running Terminal started before the profile was installed (it compares Terminal's own `LastTerminalStartTime` with the profile file's mtime).

`nekoshell theme <flavour>` re-renders and re-installs the profile in the new flavour. `nekoshell doctor` checks that the profile is installed, that it is the default, that its font decodes to the Nerd Font, and whether this macOS draws 24-bit colour.

## Panel

Terminal.app has no split or hotkey window that can be driven without an automation prompt. `nekoshell music` inside Terminal.app writes `~/.local/share/nekoshell/terminal-app/nekoshell-music.command` (a login-shell script that runs the player) and opens it with `open -a Terminal`, which gives the player a new window under the nekoshell profile and asks nothing. The window closes when the player quits. Inside tmux the shared popup is used instead, and from any other terminal the player runs in place.

## Images

None. Terminal.app draws no inline images, so the greeting falls back to text, and it has no background image setting.

## Uninstall

`nekoshell terminal remove terminal-app` (and `nekoshell uninstall`) sets the default and startup profiles back to the recorded previous name, unless you have since chosen another one, removes the `nekoshell` entry from "Window Settings" by exporting the domain, dropping that one key and importing it again, and deletes the two files under `~/.local/share/nekoshell/terminal-app`. Nothing else in the preferences is touched.

## Known limits

No inline images, no background image, and no hotkey. 24-bit colour only on macOS 26 and later; before that Terminal.app rounds every colour to the nearest of 256, so the palette is approximate and the doctor says so. The player opens in a new window rather than a docked panel. Terminal.app has no keys for the cursor text, selected text or link colours, so those roles are not set.
