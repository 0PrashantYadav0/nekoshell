# Remote hosts, Codespaces, devcontainers

nekoshell v0.1 targets macOS. This page covers what still works when you connect to a remote host over SSH, or work inside Codespaces or a devcontainer, and what does not.

## What carries over

If the remote host is a Mac and you install nekoshell there directly:

```bash
./install.sh --yes --skip-spotify
```

`--skip-spotify` skips the "run `spotify_player authenticate`" hand-off line, since a remote session usually has no browser to authenticate with.

Once installed, these work the same as local:

- The zsh config and Starship prompt.
- Your aliases (`~/.config/nekoshell/zsh/local.zsh` and the shipped `aliases.zsh`).
- bat, eza, fzf, and zoxide, if you also installed them (Linuxbrew works for these on Linux hosts).
- The greeting, but only when both are true:
  - `NEKOSHELL_GREET_SSH=1` is set (the greeting is off over SSH by default).
  - fastfetch and pokemon-colorscripts are installed on that host.

## What does not carry over

- **Fonts.** The Nerd Font icons only render in a local terminal that has the font installed. A remote shell inherits whatever font your local terminal is already using.
- **The iTerm2 panel.** The hotkey window is a local iTerm2 feature; it has no remote equivalent.
- **Spotify.** Neither spotify_player nor the shpotify remote control a Spotify session from inside an SSH connection.

## Linux hosts, Codespaces, devcontainers

`install.sh` checks `uname -s` and refuses to run on anything but Darwin. There is no Linux port yet. To get the shell config working on a Linux host today, copy two pieces by hand and source them from your own shell config:

```bash
mkdir -p ~/.config/nekoshell-zsh
cp ~/.local/share/nekoshell/stow/config/.config/starship.toml ~/.config/starship.toml
cp ~/.local/share/nekoshell/stow/config/.config/nekoshell/zsh/*.zsh ~/.config/nekoshell-zsh/
```

Then add to your `.zshrc`:

```bash
export STARSHIP_CONFIG="$HOME/.config/starship.toml"
eval "$(starship init zsh)"
for f in "$HOME"/.config/nekoshell-zsh/*.zsh; do source "$f"; done
```

For Codespaces, point your dotfiles repository setting at this repo, but wait for Linux support before expecting `install.sh` to run there. There is no `remote/bootstrap.sh` shipped in v0.1; the manual copy above is the only path until Linux support lands.
