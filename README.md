# nekoshell

A Catppuccin-themed iTerm2 rig with a Pokémon greeting, machine stats, and a hotkey Spotify panel, installed by one idempotent script.

![Greeting](docs/screenshots/greeting.png)
![Panel](docs/screenshots/panel.png)

## What you get

**Look**: Catppuccin Mocha, JetBrainsMono Nerd Font, Starship prompt, eza, bat, fzf, zoxide, delta, btop, lazygit.

**Greeting**: a new interactive terminal prints art next to machine stats. The art is a Pokémon colourscript 70 percent of the time and a picture from your art pack the other 30 percent. Stats come from fastfetch. The greeting finishes in under 150 ms and never runs inside tmux, over SSH, or inside Claude Code. The Art line shows the Pokémon's name, national dex number, type and generation.

**Panel**: press ⌥M anywhere to show or hide an iTerm2 hotkey window docked to the right edge of the screen, running spotify_player. Spotify Premium is required for playback; without it, the panel falls back to a shpotify remote for the Spotify desktop app.

## Install

```bash
git clone https://github.com/0PrashantYadav0/nekoshell.git ~/.nekoshell
cd ~/.nekoshell
./install.sh
```

Then, by hand:

1. Quit and reopen iTerm2.
2. Run `spotify_player authenticate` (opens a browser, needs Spotify Premium).
3. Press ⌥M to open the panel.

Check everything worked:

```bash
nekoshell-doctor
```

## Install with an AI agent

Paste this into your agent:

> Install https://github.com/0PrashantYadav0/nekoshell on this Mac by following its AGENTS.md

For agents that support skills:

```bash
npx skills add 0PrashantYadav0/nekoshell
```

## Customise

- Your own aliases and functions: `~/.config/nekoshell/zsh/local.zsh`.
- Greeting mix (Pokémon share, shiny odds, image size): `~/.config/nekoshell/greet.conf`, copied there on install and never overwritten.
- Add images to the art pack: `nekoshell-art add <image>`. `nekoshell-art sample` seeds it with the three shipped images.
- Change the hotkey: edit `HotKey Key Code` and `HotKey Modifier Flags` in `iterm2/build-profiles.py`, then re-run `./install.sh`.
- Change the theme: edit the `MOCHA` dict in `iterm2/build-profiles.py`, the palette in `stow/config/.config/starship.toml`, and the bat, btop and lazygit theme files under `stow/config/.config/`, then re-run `./install.sh`.

## Uninstall

```bash
./uninstall.sh
```

This unstows the linked configs, restores the files it backed up, and removes the iTerm2 profiles.

It does not undo everything. It deliberately leaves behind:

- the `[include]` line it added to `~/.gitconfig`
- `~/.local/bin/pokemon-colorscripts` and its clone in `~/.local/share/pokemon-colorscripts`
- your own files in `~/.config/nekoshell/`: `zsh/local.zsh`, `greet.conf` and `art/`
- the cache in `~/.cache/nekoshell`
- the five other iTerm2 defaults it wrote: `HideTab`, `TerminalMargin`, `TerminalVMargin`, `PromptOnQuit`, `HideScrollbar`
- Homebrew packages

It prints the commands for the last two so you can finish by hand if you want to.

## More

- [docs/INSTALL.md](docs/INSTALL.md): install steps for a human, with troubleshooting.
- [docs/REMOTE.md](docs/REMOTE.md): what carries over to SSH hosts and devcontainers.
- [AGENTS.md](AGENTS.md): the install contract for an AI agent.
- [CONTRIBUTING.md](CONTRIBUTING.md): how to run the tests and linter.
- [CHANGELOG.md](CHANGELOG.md): what changed per version.

## Credits

[Catppuccin](https://github.com/catppuccin), [pokemon-colorscripts](https://gitlab.com/phoneybadger/pokemon-colorscripts) (sprites from [PokeSprite](https://github.com/msikma/pokesprite); Pokémon is a trademark of The Pokémon Company), [fastfetch](https://github.com/fastfetch-cli/fastfetch), [spotify_player](https://github.com/aome510/spotify-player), [Starship](https://starship.rs), [iTerm2](https://iterm2.com).
