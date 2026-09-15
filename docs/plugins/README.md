# Plugins

How the plugins work from a user's side, then one page per plugin. Each plugin's own README (`plugins/<name>/README.md`, printed by `nekoshell plugin info NAME`) is the contract: what it installs, which files it touches, what removing it leaves. The pages here are the manual: what you get day to day, the keys, commands and aliases, which files are yours to edit, how each follows the theme, and how to turn it off.

How a plugin is built, hook by hook: [ARCHITECTURE.md](ARCHITECTURE.md).

## Managing plugins

```bash
nekoshell plugin list                 # every plugin, one line: enabled, available or unavailable
nekoshell plugin info tmux            # its plugin.toml and README
nekoshell plugin add aerospace p10k   # enable one or more
nekoshell plugin remove btop          # disable; copied configs stay
nekoshell plugin remove --purge btop  # also uninstall its Homebrew formulas
nekoshell doctor --plugin spotify     # one plugin's doctor rows only
```

`add` installs the Homebrew taps, formulas and casks the plugin names, links and copies its files, runs its install hook, renders its themed files for the flavour in force, records the plugin in `~/.config/nekoshell/nekoshell.toml`, regenerates `~/.config/nekoshell/antidote.txt` and prints the plugin's doctor rows. A plugin that needs another (`requires_plugins`) adds it first; one that conflicts with an enabled plugin refuses; one that does not support the terminal you run it from refuses too, and `plugin list` shows it as `unavailable`.

`remove` runs the uninstall hook, removes the symlinks that point into the checkout, drops the plugin from the enabled list and regenerates the antidote bundle. Copied and rendered files stay unless the plugin's page says otherwise. `--purge` uninstalls the Homebrew formulas in the plugin's `requires` list, and then its casks, whenever no other enabled plugin lists them.

A new shell picks up the change. Plugins load in the order they were enabled.

## Profiles

The installer asks for a profile, or takes `--profile`:

| Profile | Plugins |
| --- | --- |
| `minimal` | modern-cli, greet, pokemon |
| `dev` | minimal plus fzf, atuin, lazygit, btop, nvim, tmux |
| `full` | dev plus spotify |
| `pick` | a menu that toggles plugins one by one |

`--with a,b` and `--without c` adjust any of them. anime, minecraft, colorscripts, yazi, gh, mise, pure, ai, claude-code, opencode, aerospace, p10k and omz are in no profile: add them by hand.

## What a plugin puts in your home

- **Linked.** Files under `plugins/<name>/files/link/` are symlinked into `$HOME` at the same relative path. A real file already there is moved into `~/.local/share/nekoshell/backup/<timestamp>/` first. The link points into the checkout, so editing the file edits the repository copy, and `git pull` changes it. Removing the plugin removes the link.
- **Copied once.** Files under `plugins/<name>/files/copy/` are copied into `$HOME` when missing and never written again. They are yours: edit them freely, and removing the plugin leaves them in place. A plugin with a `copy_guard` (nvim, tmux, aerospace, p10k, spotify, yazi, mise) skips the whole copy when a config of your own is already at the guarded path and says so; the shipped files stay readable in the checkout.
- **Rendered.** Some plugins write a file from a template on `plugin add` and on every `nekoshell theme <flavour>`: the fastfetch config, the tmux flavour file, the p10k and pure colours, the spotify theme, the yazi theme. Each starts with a header that names nekoshell. Edits to a rendered file are lost on the next switch; a file of your own at the same path is backed up before the first render.
- **Touched in place.** Three plugins edit a line or a region of a file that is otherwise yours: modern-cli appends an `[include]` region to `~/.gitconfig`, btop rewrites the `color_theme` line of `~/.config/btop/btop.conf`, spotify rewrites the `theme` and `client_id` lines of `~/.config/spotify-player/app.toml`, claude-code sets the `theme` and `statusLine` keys of `~/.claude/settings.json` and opencode the `theme` key of `~/.config/opencode/tui.json`, each with the previous value recorded and restored on removal.

## Hooks you may notice

- `install.sh` runs on add: modern-cli edits `~/.gitconfig`, pokemon, minecraft and colorscripts clone their sprite packs at a pinned commit and anime downloads its release tarball, tmux clones TPM, spotify replaces an old symlinked `app.toml` with a copy.
- `theme.sh` runs on add and on every theme switch and writes the rendered files above; btop rewrites its one line, modern-cli rebuilds bat's theme cache.
- `uninstall.sh` runs on remove and takes back what the install hook did.
- `doctor.sh` adds rows to `nekoshell doctor`; `--plugin NAME` shows one plugin's rows.
- `early.zsh`, `plugin.zsh` and `late.zsh` are sourced by the zshrc at the very start of the shell, after the antidote bundle, and after the prompt is set up. `bin/` goes on `PATH`, `antidote.txt` lines join the shell plugin bundle, `greet-art` makes the plugin an art provider for the greeting, and `cmd/<name>.sh` becomes `nekoshell <name>`; `nekoshell help` lists those under "Plugin commands".

## The plugins

| Plugin | What it is | Tags | Needs |
| --- | --- | --- | --- |
| [modern-cli](modern-cli.md) | eza, bat, fd, ripgrep and delta in place of ls, cat and the git pager, plus zoxide's `z` for jumping | shell | eza, bat, fd, ripgrep, zoxide, git-delta |
| [greet](greet.md) | a sprite from an art provider or your own pixel art next to fastfetch's machine stats on every new shell | look | fastfetch |
| [pokemon](pokemon.md) | a random Pokémon in the greeting, with its number, type and generation | look | pokemon-colorscripts, cloned |
| [anime](anime.md) | a random anime character in the greeting | look | anime-colorscripts, a release tarball |
| [minecraft](minecraft.md) | a random Minecraft block in the greeting | look | minecraft-colorscripts, cloned |
| [colorscripts](colorscripts.md) | an ANSI pattern in the terminal's palette in the greeting | look | theamallalgi/colorscripts, cloned |
| [fzf](fzf.md) | Ctrl-T, Alt-C and Ctrl-R with previews | shell | fzf |
| [atuin](atuin.md) | searchable shell history on Ctrl-R, kept on this machine | shell | atuin |
| [lazygit](lazygit.md) | a terminal UI for git, on `lg` | shell | lazygit |
| [btop](btop.md) | a resource monitor on `top`, in the flavour | shell | btop |
| [nvim](nvim.md) | Neovim with lazy.nvim, Catppuccin, treesitter and telescope | editor | neovim |
| [tmux](tmux.md) | tmux with a `C-a` prefix, vim-style panes and the Catppuccin status line | shell | tmux; TPM, cloned |
| [spotify](spotify.md) | Spotify in the terminal: spotify_player, or a remote for the desktop app | media | spotify_player, shpotify; Spotify Premium to stream |
| [aerospace](aerospace.md) | AeroSpace, an i3-style tiling window manager | system | the `aerospace` cask from `nikitabobko/tap`; an Accessibility grant |
| [p10k](p10k.md) | Powerlevel10k as the prompt instead of Starship | prompt, shell | powerlevel10k |
| [yazi](yazi.md) | yazi, a terminal file manager, in the flavour; `y` lands you where you quit | shell | yazi |
| [gh](gh.md) | GitHub's CLI with cached completions and delta as its pager | shell | gh |
| [mise](mise.md) | one tool for every runtime version, activated in every shell | shell | mise |
| [pure](pure.md) | the pure prompt instead of Starship | prompt, shell | pure |
| [ai](ai.md) | a welcome banner (tool, project, branch, last commit) in front of AI coding tools | ai | nothing |
| [claude-code](claude-code.md) | Claude Code in the flavour: a custom theme, a status line, the banner | ai | Claude Code, installed on its own |
| [opencode](opencode.md) | OpenCode in the flavour: a theme and the banner | ai | opencode |
| [omz](omz.md) | oh-my-zsh's git aliases and web-search, without oh-my-zsh | shell | nothing from Homebrew; antidote clones oh-my-zsh on the first shell |
| [vscode](vscode.md) | VS Code opens the nekoshell terminal from Ctrl+Shift+C and the Explorer | editor | VS Code, installed on its own |
