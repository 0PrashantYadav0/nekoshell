# Installing over SSH

nekoshell runs on macOS only: `install.sh` checks `uname -s` and stops on anything else, and there is no Linux port. This page is about installing it on another Mac that you reach over SSH, and what behaves differently there.

## Install on the remote Mac

Over an SSH session there is no terminal app to detect and nobody to answer a menu, so give the installer everything on the command line:

```bash
ssh other-mac
git clone https://github.com/0PrashantYadav0/nekoshell.git ~/.nekoshell
cd ~/.nekoshell
./install.sh --yes --profile dev --terminal installed
```

`--terminal installed` configures every terminal whose app is on that Mac; name one instead (`--terminal iterm2`) when you know which one its owner uses. Homebrew, zsh and git have to be there already, and so do Starship, antidote and the Nerd Font, which the installer does not install (see [INSTALL.md](INSTALL.md)). `nekoshell doctor` on the remote Mac reports what is missing.

The human steps are the same as a local install and have to be done at that Mac: quitting and reopening Terminal.app, quitting iTerm2 and running `nekoshell terminal apply` for its global preferences, granting Ghostty Accessibility, signing in to Warp, `spotify_player authenticate`, and `C-a I` inside tmux. Each terminal's `terminals/<id>/README.md` says which apply to it.

## What an SSH session sees

The shell config, prompt, aliases, fzf, atuin and the modern-cli tools work the same inside the SSH session, since they run on the remote Mac.

The greeting is silent over SSH. `plugins/greet/late.zsh` and the greet script both check `SSH_CONNECTION` and skip the greeting unless `NEKOSHELL_GREET_SSH` is set to exactly `1`; setting it to `0` means no. Put `export NEKOSHELL_GREET_SSH=1` in `~/.config/nekoshell/zsh/local.zsh` on the remote Mac to get it back, and note that inline images then depend on the terminal you are connecting from, not the one configured on the remote Mac.

The panel and the terminal configuration are for the remote Mac's own windows. `nekoshell music` inside an SSH session finds no terminal adapter for the connection and runs the player in place; inside tmux it opens a popup, which works anywhere. Fonts and colours are drawn by your local terminal, so what you see over SSH is your local terminal's font and its own theme.

## What an AI agent does

An agent installing nekoshell on a Mac it reaches over SSH follows [AGENTS.md](https://github.com/0PrashantYadav0/nekoshell/blob/main/AGENTS.md) unchanged: the same non-interactive install line, `nekoshell doctor --json` to verify, and the human steps handed back rather than attempted. The only difference is that the terminal cannot be detected, so the agent passes `--terminal installed` or a named id.
