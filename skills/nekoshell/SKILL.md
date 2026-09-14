---
name: nekoshell
description: Install the nekoshell terminal rig (Catppuccin look, Pokémon greeting with machine stats, a music panel, five macOS terminals) on a Mac by running its installer and doctor, then handing the human the steps only they can do.
---

# nekoshell

Follow `AGENTS.md` in <https://github.com/0PrashantYadav0/nekoshell> exactly. In short:

1. Check preconditions: macOS, Homebrew, zsh, git. The installer itself brings Starship, antidote and the Nerd Font through Homebrew.
2. Install, non-interactively:

   ```bash
   [ -d ~/.nekoshell ] || git clone https://github.com/0PrashantYadav0/nekoshell.git ~/.nekoshell
   cd ~/.nekoshell && git pull --ff-only && ./install.sh --yes --profile full --terminal installed
   ```

   `--terminal all` configures every terminal with an adapter instead of only the installed ones. Do not add the `aerospace` plugin unless the human asked for it.
3. Verify with `nekoshell doctor --json`; exit 0 is success. `warn` rows on `iterm2 prefs`, `terminal-app default`, `ghostty hotkey`, `spotify login` and `greet time` are expected on a fresh machine; only a `fail` row blocks, and its detail names the fix.
4. Tell the human the steps that apply, then stop: quit iTerm2 and run `nekoshell terminal apply`; quit and reopen Terminal.app; grant Ghostty Accessibility and restart it; sign in to Warp; run `nekoshell spotify login`; run `tmux` and press `C-a I` once; open `nvim` once. Do not start a tmux session yourself.

The look is Catppuccin mocha by default; `nekoshell theme latte` (or frappe, macchiato, `auto`) switches every themed file at once. Run it only when the human asks for a different flavour.

Never delete `~/.local/share/nekoshell/backup/`. Roll back with `./uninstall.sh --yes`; it restores the backups and leaves the user's own files in `~/.config/nekoshell/`, the copied configs, the sprite packs under `~/.local/share` and the Homebrew packages in place.
