# yazi

## What you get

yazi, a terminal file manager with previews, in the flavour. `y` opens it and, on quit, changes the shell's directory to the one you were in. File previews use bat, fd, ripgrep and zoxide when the modern-cli plugin put them on PATH; image, video and PDF previews need `ffmpeg`, `poppler`, `resvg` and `imagemagick`, which the plugin does not install.

## Using it

| Command | What it does |
| --- | --- |
| `y` | open yazi here; `q` quits and leaves the shell where you were |
| `yazi` | open yazi without the directory change |
| `nekoshell doctor --plugin yazi` | is yazi there, is the theme rendered for the flavour |

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.config/yazi/yazi.toml` | copied once; one of your own is left alone | yes |
| `~/.config/yazi/theme.toml` | rendered on add and on every theme switch | no: edit `plugins/yazi/files/theme.toml.tmpl` instead. A theme of your own at that path is backed up before the first render |

## Theme

The template is yazi's own Catppuccin flavour with every colour replaced by its palette role, rendered for the flavour in force on every `nekoshell theme <flavour>`. A running yazi needs to be restarted to pick it up.

## Turning it off

`nekoshell plugin remove yazi` removes the `y` function and the rendered `theme.toml`; `yazi.toml` stays. `--purge` also uninstalls yazi.
