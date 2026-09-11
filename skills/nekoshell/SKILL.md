---
name: nekoshell
description: Install the nekoshell terminal rig (Catppuccin iTerm2 look, Pokémon greeting with machine stats, hotkey Spotify panel) on a Mac by running its installer and doctor, then handing the human the steps only they can do.
---

# nekoshell

Follow `AGENTS.md` in https://github.com/0PrashantYadav0/nekoshell exactly. In short:

1. Check preconditions: macOS, Homebrew, iTerm2, zsh.
2. `[ -d ~/.nekoshell ] || git clone https://github.com/0PrashantYadav0/nekoshell.git ~/.nekoshell; cd ~/.nekoshell && git pull --ff-only && ./install.sh --yes`
3. `bin/nekoshell-doctor --json`; exit 0 is success. `warn` on `spotify`, `iterm2 prefs` or `greet time` is expected on a fresh machine; only `fail` blocks.
4. Tell the human: restart iTerm2, run `spotify_player authenticate`, press ⌥M, then run `tmux` and press `C-a I` once to install the tmux plugins. If prefs are pending, they run `install.sh --iterm-prefs` with iTerm2 closed. Do not start a tmux session yourself.

The look is Catppuccin mocha by default; `nekoshell-theme latte` (or frappe, or macchiato) switches
every themed file at once. Run it only when the human asks for a different flavour: it overwrites
`~/.config/starship.toml` and `~/.config/fastfetch/config.jsonc`, which are otherwise theirs.

Never delete `~/.local/share/nekoshell/backup/`. Roll back with `./uninstall.sh --yes`; it restores the
backup but leaves the user's own files in `~/.config/nekoshell/`, the pokemon-colorscripts install, the
`~/.gitconfig` include and the Homebrew packages in place.
