# Configuration

Three files hold everything you can change: `nekoshell.toml`, which the installer writes and the rest of the rig reads; `greet.conf`, which is the greeting's; and `local.zsh`, which is your own shell. All three are under `~/.config/nekoshell/`.

## nekoshell.toml

`~/.config/nekoshell/nekoshell.toml` is written by the installer and read by everything else, including the zshrc, which parses it with zsh's own parameter expansion rather than starting a process. It is a flat TOML subset: one key per line, arrays on one line, no escapes.

| Key | Meaning |
| --- | --- |
| `root` | the checkout; the doctor fails when it does not match |
| `terminal` | the primary terminal, used by a shell that is not in any configured one |
| `terminals` | every configured terminal; the doctor, theme switches and uninstall walk this list |
| `theme` | `auto` or a flavour |
| `theme_resolved` | the flavour the last switch rendered |
| `theme_auto_dark`, `theme_auto_light` | what `auto` maps the two macOS appearances to (mocha and latte) |
| `profile` | the profile the installer used |
| `plugins` | the enabled plugins, in the order they were enabled |
| `music_player` | the plugin `nekoshell music` runs; `auto` takes the first one tagged `media` |
| `background`, `background_opacity` | the background image, re-applied on every theme switch |
| `ghostty_quick_terminal` | `"shell"` keeps Ghostty's quick terminal a plain shell instead of the music panel |
| `terminal_app_previous_default` | the Terminal.app profile to put back on removal |

`nekoshell terminal use`, `nekoshell theme` and `nekoshell plugin add|remove` write the keys they own, so the file rarely needs editing by hand. Which library writes which key is in [ARCHITECTURE.md](ARCHITECTURE.md).

## Themes

Four Catppuccin flavours: latte, frappe, macchiato and mocha, mocha by default.

```bash
nekoshell theme list      # frappe, latte, macchiato, mocha
nekoshell theme latte     # switch everything
nekoshell theme current   # the flavour in force
nekoshell theme auto      # follow the macOS appearance
```

A switch re-renders the prompt, the shell colours (`~/.config/nekoshell/theme.zsh`, which carries bat, fzf, syntax highlighting and autosuggestions), every configured terminal and every enabled plugin's themed files, all from one palette file, `core/theme/palettes.json`. That file is the only place in the repository a colour is written down. The shell colours are why commands are tinted as you type them and why the autosuggestion behind the cursor sits in the palette's dimmest readable grey.

`auto` renders mocha when macOS is dark and latte when it is light; `theme_auto_dark` and `theme_auto_light` in `nekoshell.toml` change the pair. Each new interactive shell re-resolves it in the background, so the rig follows the system appearance without a command. Which terminals pick the new colours up on their own, and which want a reload, is in [TERMINALS.md](TERMINALS.md).

The font is JetBrainsMono Nerd Font at 15 points in every configured terminal; the installer asks Homebrew for the cask when it is missing.

## The prompt

Starship, in two lines, rendered from `core/starship/starship.toml.tmpl` into `~/.config/starship.toml` on every theme switch. The first line carries the working directory, the git branch, status and state, and the version of whatever language the directory holds (Node, Python, Rust, Go, a Docker context); the right of that line carries the last command's duration, its exit status, background jobs and the clock. The second line is the prompt character alone.

Two plugins replace it: [p10k](plugins/p10k.md) puts Powerlevel10k in its place and [pure](plugins/pure.md) the pure prompt, both in the flavour's colours. A `plugin.zsh` that sets `NEKOSHELL_PROMPT` is what takes the prompt over, so removing the plugin gives Starship back.

## greet.conf

`~/.config/nekoshell/greet.conf` is copied into your home once by the greet plugin and is yours from then on. It is sourced by bash, so keep it to `KEY=VALUE`.

| Key | Effect |
| --- | --- |
| `ART` | which art provider draws: `auto` for equal odds among the enabled ones, or weights such as `pokemon:70,anime:30` |
| `SPRITE_SHARE` | the percentage of launches that show a provider's art rather than a picture from your own art pack (70) |
| `IMAGE_WIDTH`, `IMAGE_HEIGHT` | the art pack image size in terminal cells (28 by 14); an image provider sizes its pictures from `IMAGE_HEIGHT` too |

Each provider's own keys live in the same file, prefixed with the provider's name: `POKEMON_SHINY_ODDS`, `ANIME_ONLY`, `ANIME_SKIP`, `ANIME_HEIGHT`. Each provider's page under [plugins/](plugins/README.md) lists its own. The greeting also reads a few environment variables, `NEKOSHELL_NO_GREET`, `NEKOSHELL_GREET_SSH` and the rest; they are in [plugins/greet.md](plugins/greet.md).

`nekoshell art list|add|sample` manages the art pack itself, which lives in `~/.config/nekoshell/art/`.

## local.zsh

`~/.config/nekoshell/zsh/local.zsh` is yours. The core zshrc sources it last, after the prompt, the plugins and everything nekoshell renders, so anything in it wins. It is never overwritten, and an uninstall leaves it alone. When the installer replaces an existing `~/.zshrc` it moves the aliases and exports it finds there into this file first.

Two files beside it, `aliases.zsh` and `env.zsh`, are symlinks into the checkout and belong to nekoshell: edit the copies under `core/zsh/` instead, or override them in `local.zsh`.

## Configs plugins put in your home

Some plugins copy a config into your home once and then leave it to you (Neovim, tmux, AeroSpace, yazi, mise, `~/.p10k.zsh`, spotify-player's `app.toml`, the ai plugin's welcome templates). Others render a file from a template and rewrite it on every theme switch, so an edit to a rendered file is lost; edit the template in the checkout instead. Which is which, per plugin, is in [plugins/README.md](plugins/README.md) under "What a plugin puts in your home".
