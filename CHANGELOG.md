# Changelog

## 0.2.0 (unreleased)

A rebuild around one command and a plugin layout. `nekoshell install`, `doctor`, `theme`, `terminal`, `plugin`, `music` and `uninstall` replace the v0.1 scripts; `install.sh` and `uninstall.sh` only check for macOS and Homebrew and hand over. The v0.1 command names stay as three-line shims onto the subcommands.

### Plugins and profiles

- Everything past the shell and the prompt is a plugin under `plugins/<name>/`: a `plugin.toml` with nine keys, optional install, uninstall, theme and doctor hooks, files to link or copy, zsh to source, and commands the plugin adds to `nekoshell`. Ten ship: modern-cli, greet, fzf, atuin, lazygit, btop, nvim, tmux, spotify and aerospace.
- Profiles name plugins: `minimal`, `dev` and `full`, or `pick` to choose by hand; `--with` and `--without` adjust the list.
- Copied configs (Neovim, tmux, AeroSpace, greet.conf) are the user's after the first install; a config already at a guarded path skips the whole copy and says so.
- `nekoshell music` opens the first enabled plugin tagged `media`, or the `music_player` setting, in the running terminal's panel.

### Five terminals

- Adapters for iTerm2, kitty, Ghostty, Warp and Apple Terminal.app, each behind the same ten functions: font, colours, a music panel, a background image where the terminal can draw one, a doctor block and a clean removal. Every colour comes from `core/theme/palettes.json`.
- `nekoshell terminal use a,b|all|installed` configures several terminals; the theme, the doctor, `terminal background` and uninstall walk the whole list, and the running terminal is the one the greeting draws in and the panel opens from.
- The core zshrc sources the running terminal's own hook (`terminals/<id>/zsh.zsh`); Ghostty's turns the quick terminal into the music panel.
- `nekoshell theme auto` follows the macOS appearance; each new shell re-resolves it in the background.

### Repository

- One linter, `scripts/lint.sh` (shellcheck, shfmt, the repository shape rules, actionlint, yamllint, markdownlint), conventional commit messages checked by `scripts/check-commit-msg.sh`, git hooks installed by `make hooks`, and four required CI jobs: lint, test, install (once per terminal adapter) and commits.
- `tests/core/repo.bats` guards the plugin and adapter contracts and keeps code off the v0.1 layout. Every shell file is formatted with `shfmt -i 2 -ci -bn`.

### Fixes

- A user's own `~/.config/starship.toml` or fastfetch config is backed up before the first render, and uninstall restores every backup set, not only the newest.
- A dry run records nothing: `--dry-run` and `--check` no longer leave the toml naming plugins or a theme that were never installed.
- A v0.1 machine is migrated: the recorded flavour is kept, the profile defaults to `full`, and the twelve stale links v0.1 left are swept.
- The zshrc sources iTerm2's shell integration, so the status bar's directory and git components fill in, and uninstall removes the iTerm2 dynamic profile.
- The greeting and `bin/nekoshell` resolve a link to a link, `help` and `version` create nothing in `$HOME`, and plugins are handed the flavour in force rather than mocha when nothing is recorded yet.

Verified on macOS 26 (Tahoe) with iTerm2, kitty, Ghostty, Warp and Terminal.app installed; see the terminal READMEs for the human steps each still needs.

## 0.1.0

The first version: an iTerm2-only rig installed by one script that stowed its configs into the home directory. It had the Catppuccin flavours switched by `nekoshell-theme`, the Pokémon greeting with fastfetch stats, the ⌥M Spotify panel as an iTerm2 hotkey window, fzf previews, atuin, Neovim and tmux configs copied once, opt-in AeroSpace, a Brewfile, a doctor and an uninstaller. v0.2 replaces its layout entirely; the installer migrates a v0.1 machine.
