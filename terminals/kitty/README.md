# kitty

## What it configures

nekoshell writes two files of its own into kitty's config directory (`~/.config/kitty`, or wherever `KITTY_CONFIG_DIRECTORY` or `XDG_CONFIG_HOME` points) and adds one include line to `kitty.conf`. `nekoshell.conf` is rendered from `terminals/kitty/nekoshell.conf.tmpl` with the current Catppuccin flavour: the font (`JetBrainsMono Nerd Font` at 15pt), the sixteen ANSI colours, foreground, background, cursor, selection, URL, border, tab bar and mark colours, 12pt window padding, a titlebar-only window, a powerline tab bar, Option as Alt, remote control over a socket, and the alt+m mapping for the music panel. `nekoshell-panel.conf` is the quick-access terminal's config, rendered from `nekoshell-panel.conf.tmpl` so it carries the flavour's background colour.

`kitty.conf` gets two lines at its end, `# nekoshell` and `include nekoshell.conf`, added once and never twice. kitty reads the file top to bottom and the last value wins, so nekoshell's settings override whatever the file already sets; move the two lines up if you want your own settings to win. A `kitty.conf` you already had is backed up once, into `~/.local/share/nekoshell/backup`, before the first edit. If there is no `kitty.conf`, one is created holding just those two lines.

kitty reads its config when a window opens. After `nekoshell terminal apply` or `nekoshell theme`, a shell running inside kitty asks its own window to reload through the remote-control socket; a kitty that was started before that socket was configured refuses, and the change then shows in the next new window or after ctrl+shift+f5 in an open one.

A background image goes through `terminal_background`: kitty draws PNG, so any other format is converted with `sips` into `~/.local/share/nekoshell/kitty-background.png`. The image is written as `background_image` with `background_image_layout scaled` and `background_tint` set to one minus the opacity, so an opacity of 0.85 lays 15% of the background colour over the picture. The choice is recorded in `nekoshell.toml` as `background` and `background_opacity` and rendered again on every theme switch; `none` takes the lines out.

## Panel

The music panel is kitty's quick-access terminal kitten, docked to the right edge of the screen, 60 columns wide, 95% opaque, running `nekoshell music --here`. It appears when asked for and hides again when it loses focus. Press alt+m in any kitty window to show it, and alt+m again to hide it; `nekoshell music` from a shell inside kitty does the same. Inside tmux, `nekoshell music` uses a tmux popup instead, as every adapter does. The panel is its own kitty instance and reads your `kitty.conf`, so it has the same font, colours and keys as the main window.

## Images

kitty draws inline images with its own graphics protocol. The adapter claims `images`, and the greet plugin passes `--kitty` to fastfetch, so the greeting's art pack is drawn as a picture rather than as ASCII.

## Uninstall

`nekoshell terminal remove kitty` and `nekoshell uninstall` delete `nekoshell.conf`, `nekoshell-panel.conf` and the converted background PNG, and take the `# nekoshell` and `include nekoshell.conf` lines back out of `kitty.conf`. Everything else in `kitty.conf` stays as it was; the file itself is deleted only when nothing but those two lines was ever in it. `nekoshell uninstall` also puts the backed-up `kitty.conf` back.

## Known limits

alt+m works while a kitty window is focused. kitty has no global hotkey of its own on macOS; to open the panel from another application, give the `Quick access to kitty` entry a shortcut under System Settings, Keyboard, Keyboard Shortcuts, Services, or use a launcher such as skhd or Raycast to run `kitten quick-access-terminal --config ~/.config/kitty/nekoshell-panel.conf`. Changes to `kitty.conf` apply to new windows, or after ctrl+shift+f5 in an open one; the live reload after an apply only works from a shell inside a kitty that started with `allow_remote_control socket-only` already in its config, which is the second kitty you launch after the first apply. The background image is per config, not per window: every kitty window shows it. The quick-access terminal needs kitty 0.42 or newer.
