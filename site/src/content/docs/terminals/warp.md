# Warp

## What it configures

Three things under `~/.warp`, which is where Warp 0.2026.09.09 keeps everything on macOS.

A custom theme, `~/.warp/themes/nekoshell_<flavour>.yaml`, rendered from `theme.yaml.tmpl` so every colour still comes from `core/theme/palettes.json`. Only the flavour in force has a file; a theme switch replaces it. Warp watches the themes directory and lists the file within seconds.

Three keys in Warp's own settings file, `~/.warp/settings.toml`: `appearance.themes.theme` (set to the custom theme), `appearance.text.font_name` (`JetBrainsMono Nerd Font`) and `appearance.text.font_size` (`15.0`). Warp hot-reloads this file, so the change shows while Warp is running and it never has to be quit. The file is the user's (the Settings panel writes it too) and TOML has no include, so `settings.py` edits just those keys in place, tagging each line `# nekoshell`, and leaves every other line alone. Before the first edit the file goes into the backup set once and what the three keys said is written to `~/.config/nekoshell/warp-previous.toml`, so remove can put it back.

A tab config, `~/.warp/tab_configs/nekoshell_music.toml`, which is the music panel (see below).

This Warp does not read its theme or font from the `dev.warp.Warp-Stable` defaults domain any more. A first launch on this Mac wrote only `AppAddedAsLoginItem`, `ExperimentId`, `NSAutoFillHeuristicControllerEnabled` and `SettingsFileMigrationComplete` there; the app itself carries the message "Migrating public settings from native store to settings.toml", and Warp's file-locations page lists the defaults domain as legacy. So nothing here calls `defaults`.

## Panel

`nekoshell music` inside Warp runs `open "warp://tab_config/nekoshell_music?new_window=true"`, which opens the tab config in a new Warp window; the config's one pane runs `nekoshell music --here` with `NEKOSHELL_PANEL=1`. The same tab config appears in Warp's `+` menu as "nekoshell music". Inside tmux the tmux popup is used instead, and outside Warp the player runs in the current window.

## Images

`images` is claimed. Warp's changelog announces support for both the Kitty image protocol and the iTerm image protocol on macOS, and the binary carries the Kitty implementation (transmission mediums, unicode placeholders, PNG decoding), so fastfetch's `--kitty` logo works, and `--iterm` should too. Neither could be watched on this Mac because Warp stops at its sign-in screen before a shell opens.

A background image is supported through the theme: `nekoshell terminal background PICTURE.jpg [OPACITY]` copies the picture to `~/.warp/themes/nekoshell_background.jpg` and writes a `background_image` block into the theme file with the opacity as a percentage. Warp only reads JPEG here, so a PNG is refused with a `sips` one-liner to convert it. `none` takes the image out again.

## Uninstall

`nekoshell terminal remove warp` (and `nekoshell uninstall`) deletes the theme file, the background copy and the tab config, restores `appearance.themes.theme` to what it was before the first apply (or removes the key when there was none) as long as it still names a nekoshell theme, restores the font name and size the same way as long as they are still ours, and deletes `warp-previous.toml`. A theme or font the user changed in the meantime is left as they set it.

## Known limits

The theme selection and the custom theme's `name`/`path` shape in `settings.toml` follow Warp's bundled settings schema, but no sign-in was available to watch Warp read them; see the manual check in the adapter report.

A Warp that was already open before `~/.warp/themes` existed can take a few minutes to notice the new directory; restarting Warp is quicker.

There is no key that opens the panel: `keybindings.yaml` only rebinds Warp's built-in actions, and there is no action for one tab config. Use `nekoshell music`, the `+` menu, or the deep link.

Launch configurations (the YAML format under `~/.warp/launch_configurations`) are marked legacy in Warp's docs, so the panel uses a tab config instead.

Only JPEG backgrounds, and the theme is one file per flavour, so a background set while in mocha is kept for latte too (it is re-attached on every apply).
