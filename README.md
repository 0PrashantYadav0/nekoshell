# nekoshell

A Catppuccin terminal rig for macOS: one zsh config, one prompt, a greeting with a Pokémon (or an anime character, a Minecraft block, an ANSI pattern) or your own pixel art, a music panel, and the same font and colours in iTerm2, kitty, Ghostty, Warp and Terminal.app. One command, `nekoshell`, installs it, themes it and checks it.

## What you get

**Look.** Catppuccin in any of its four flavours, mocha by default, and JetBrainsMono Nerd Font in every configured terminal. Commands are coloured as you type them and the autosuggestion behind the cursor takes the palette's dimmest readable grey. `nekoshell theme latte` moves the whole rig to another flavour; `nekoshell theme auto` follows the macOS appearance.

**Greeting.** A new interactive shell prints art next to the machine stats fastfetch collects. The art is a sprite from an art provider plugin 70 percent of the time and a picture from your art pack the rest, when the terminal can draw images. The `pokemon` provider is in every profile; `anime`, `minecraft` and `colorscripts` are one `nekoshell plugin add` away. It stays silent inside tmux, inside the panel, over SSH and under Claude Code.

**Prompt.** Starship, two lines: the working directory, git and language status on top, the last command's duration, exit status and the clock on the right. The p10k plugin puts Powerlevel10k in its place, in the flavour's colours.

**Music.** `nekoshell music` runs the music player in the current window. `nekoshell music --panel` opens it in whatever panel the running terminal has instead: a hotkey window in iTerm2, a quick-access terminal in kitty, the quick terminal in Ghostty, a popup inside tmux, a new window in Warp and Terminal.app. The spotify plugin is the player: spotify_player, which streams on its own and needs Premium, or a keyboard remote for the Spotify desktop app when spotify_player is missing or you ask for `--remote`.

**Editor and multiplexer.** Neovim with lazy.nvim, in the flavour the shell is wearing, and tmux with a `C-a` prefix, vim-style panes and a Catppuccin status line. Both are copied into your home once and are yours from then on; a config you already have is left alone.

**Search.** fzf on Ctrl-T, Alt-C and Ctrl-R with previews, atuin for a searchable shell history that never leaves the machine, and eza, bat, fd, ripgrep, zoxide and delta in place of the tools they replace.

**Five terminals.** iTerm2, kitty, Ghostty, Warp and Apple Terminal.app each have an adapter. Every one gets the font, the colours and a music panel; what differs is in the table below.

Everything past the shell and the prompt is a plugin. `nekoshell plugin list` shows the twenty that ship: modern-cli, greet, pokemon, anime, minecraft, colorscripts, fzf, atuin, lazygit, btop, nvim, tmux, yazi, gh, mise, spotify, aerospace, p10k, pure and omz. [docs/plugins/README.md](docs/plugins/README.md) is the user manual, one page per plugin.

## Install

You need macOS, Homebrew, zsh and git. Then:

```bash
git clone https://github.com/0PrashantYadav0/nekoshell.git ~/.nekoshell
cd ~/.nekoshell
./install.sh
```

The installer runs seven steps: terminal, profile, confirm, backup and core, theme, plugins, doctor. It asks two things. The terminal is the one you are running it from; when it cannot tell, it lists the installed ones and asks. The profile is `minimal` (modern-cli, greet), `dev` (adds fzf, atuin, lazygit, btop, nvim, tmux), `full` (adds spotify) or `pick`, which lets you toggle plugins one by one. Every file it replaces goes into `~/.local/share/nekoshell/backup/<timestamp>/` first, and a second run changes nothing.

The flags, for a run that should not ask:

```bash
./install.sh --yes --profile full --terminal all
./install.sh --check                      # print what would change; change nothing
./install.sh --profile dev --with spotify --without btop
```

`--terminal` takes one id, a comma-separated list, `all` for every terminal that has an adapter, or `installed` for every one whose app is on this Mac. `--yes` skips the confirmation and, with no `--profile`, picks `minimal`. `--check` implies `--dry-run`.

Step four also asks Homebrew for Starship, antidote and the JetBrainsMono Nerd Font, only for whichever is missing; plugins bring their own tools the same way. `nekoshell doctor` reports each of the three when it is still absent.

### By hand

Some steps only a person can do, and the installer prints the ones that apply at the end:

- Ghostty: grant Accessibility in System Settings, Privacy & Security, Accessibility, or the global ⌥M does nothing. Restart Ghostty once so the quick terminal's position takes effect.
- Terminal.app: quit and reopen it. It reads its profiles once, at launch.
- iTerm2: if it was running during the install, quit it and run `nekoshell terminal apply` to write the global preferences.
- Warp: sign in. Warp shows nothing until you do.
- spotify: run `nekoshell spotify login` (needs Premium), and `nekoshell spotify client-id <id>` with a Spotify app of your own so start-up is not rate-limited.
- tmux: start `tmux` and press `C-a I` once so TPM fetches the plugins.
- nvim: open it once and let lazy.nvim fetch its plugins.

[docs/INSTALL.md](docs/INSTALL.md) has the long version, upgrading, uninstalling and troubleshooting.

## Commands

| Command | What it does |
| --- | --- |
| `nekoshell install` | link the zshrc, pick a terminal and profile, apply the theme, enable plugins |
| `nekoshell doctor [--json]` | one line per check; exit 1 only when a check fails |
| `nekoshell theme list\|current\|auto\|FLAVOUR` | switch or inspect the colour theme |
| `nekoshell terminal list\|use\|remove\|apply\|background` | detect, configure and theme the terminals you use |
| `nekoshell plugin list\|info\|add\|remove` | manage plugins |
| `nekoshell music [PLAYER] [--panel]` | run the music player here, or in the terminal's panel |
| `nekoshell spotify client-id\|login\|logout` | your Spotify client id and login (spotify plugin) |
| `nekoshell greet [--image\|--text]` | print the greeting now (greet plugin) |
| `nekoshell art list\|add\|sample` | manage the greeting's art pack (greet plugin) |
| `nekoshell uninstall [--yes] [--purge]` | remove plugins, unlink the zshrc, restore your files |

`nekoshell help` lists them, with the commands enabled plugins add. What each plugin does, its keys and its files: [docs/plugins/README.md](docs/plugins/README.md).

## Terminals

| Terminal | Inline images | Background image | Panel key |
| --- | --- | --- | --- |
| iTerm2 | yes | yes | ⌥M, from any app (hotkey window) |
| kitty | yes | yes, PNG (others converted) | alt+m, inside kitty |
| Ghostty | yes | yes | ⌥M, from any app, after Accessibility is granted |
| Warp | yes | JPEG only | none; `nekoshell music --panel` or the `+` menu opens a new window |
| Terminal.app | no | no | none; `nekoshell music --panel` opens a new window |

`nekoshell terminal use all` configures every terminal with an adapter, `use installed` every one whose app is present, and `use kitty,ghostty` a named few. The running terminal is always the one the greeting and the panel act on. `nekoshell terminal background PICTURE [OPACITY]` sets a background on every configured terminal that can draw one; `none` takes it away. Each terminal's own file, `terminals/<id>/README.md`, says exactly what is written and what it cannot do.

## Themes

Four Catppuccin flavours: latte, frappe, macchiato and mocha. `nekoshell theme <flavour>` re-renders the prompt, the shell colours, every configured terminal and every enabled plugin from one palette file, `core/theme/palettes.json`. `nekoshell theme auto` follows the macOS appearance, mocha when dark and latte when light by default; each new shell re-checks it in the background.

## Configuration

`~/.config/nekoshell/nekoshell.toml` is written by the installer and read by everything else. The keys the code reads:

| Key | Meaning |
| --- | --- |
| `root` | the checkout |
| `terminal` | the primary terminal, used by a shell that is not in any configured one |
| `terminals` | every configured terminal; the doctor, theme switches and uninstall walk this list |
| `theme` | `auto` or a flavour |
| `theme_resolved` | the flavour the last switch rendered |
| `theme_auto_dark`, `theme_auto_light` | what `auto` maps the two appearances to (mocha and latte) |
| `profile` | the profile the installer used |
| `plugins` | the enabled plugins, in the order they were enabled |
| `music_player` | the plugin `nekoshell music` runs; `auto` takes the first one tagged `media` |
| `background`, `background_opacity` | the background image, re-applied on every theme switch |
| `ghostty_quick_terminal` | `"shell"` keeps Ghostty's quick terminal a plain shell |
| `terminal_app_previous_default` | the Terminal.app profile to put back on removal |

Your own shell additions go in `~/.config/nekoshell/zsh/local.zsh`, which is sourced last and never overwritten; the installer moves aliases out of an old `.zshrc` into it. The greeting's mix, shiny odds and image size are in `~/.config/nekoshell/greet.conf`, copied once and then yours.

## For AI agents

[AGENTS.md](AGENTS.md) is the contract: the exact non-interactive install line, how to verify with `nekoshell doctor --json`, how to add a plugin or a terminal adapter, and what never to do. The skill in `skills/nekoshell/` says the same thing in the shape an agent loads.

## Contributing

[CONTRIBUTING.md](CONTRIBUTING.md): `make tools`, `make hooks`, `make check`, the commit message rules and the four pull request checks. [CHANGELOG.md](CHANGELOG.md) lists what changed. [THIRD_PARTY.md](THIRD_PARTY.md) lists the vendored files.

## License

MIT, see [LICENSE](LICENSE). The sprites the greeting draws (Pokémon, anime characters, Minecraft blocks) come from their packs at greeting time and are not part of this repository; Pokémon is a trademark of The Pokémon Company and Minecraft of Mojang.
