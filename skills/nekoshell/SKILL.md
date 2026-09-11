---
name: nekoshell
description: Install the nekoshell terminal rig (Catppuccin iTerm2 look, Pokémon greeting with machine stats, hotkey Spotify panel) on a Mac by running its installer and doctor, then handing the human the steps only they can do.
---

# nekoshell

Follow `AGENTS.md` in https://github.com/0PrashantYadav0/nekoshell exactly. In short:

1. Check preconditions: macOS, Homebrew, iTerm2, zsh.
2. `git clone https://github.com/0PrashantYadav0/nekoshell.git ~/.local/share/nekoshell && cd ~/.local/share/nekoshell && ./install.sh --yes`
3. `bin/nekoshell-doctor --json`; exit 0 is success. `warn` on `spotify`, `iterm2 prefs`, or `greet time` is expected on a fresh machine; only `fail` blocks.
4. Tell the human: restart iTerm2, run `spotify_player authenticate`, press ⌥M. If prefs are pending, they run `install.sh --iterm-prefs` with iTerm2 closed.

Never delete `~/.local/share/nekoshell/backup/`. Undo with `./uninstall.sh --yes`.
