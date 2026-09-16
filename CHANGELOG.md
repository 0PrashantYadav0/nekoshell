# Changelog

## 0.3.0 (unreleased)

### Plugins

- vscode plugin: VS Code opens the nekoshell terminal from Ctrl+Shift+C and the Explorer's "Open in External Terminal". `plugin add` sets `terminal.external.osxExec` to the app for the configured terminal id and `terminal.explorerKind` to `both` in VS Code's `settings.json`, editing the JSONC file in place so comments and the other keys survive; `plugin remove` puts both keys back; `nekoshell vscode terminal [ID|App.app]` shows or changes the app, with a name outside the table passed through as it is; the doctor says which apps the debug console can open.

## 0.2.0 - 2026-09-15

A rebuild around one command and a plugin layout. `nekoshell install`, `doctor`, `theme`, `terminal`, `plugin`, `music` and `uninstall` replace the v0.1 scripts; `install.sh` and `uninstall.sh` only check for macOS and Homebrew and hand over. The v0.1 command names stay as three-line shims onto the subcommands.

### Plugins and profiles

- Everything past the shell and the prompt is a plugin under `plugins/<name>/`: a `plugin.toml` with nine keys, optional install, uninstall, theme and doctor hooks, files to link or copy, zsh to source, and commands the plugin adds to `nekoshell`. Twenty-three ship: modern-cli, greet, pokemon, anime, minecraft, colorscripts, fzf, atuin, lazygit, btop, nvim, tmux, yazi, gh, mise, spotify, ai, claude-code, opencode, aerospace, p10k, pure and omz. `docs/plugins/` has a user page for each.
- Profiles name plugins: `minimal`, `dev` and `full`, or `pick` to choose by hand; `--with` and `--without` adjust the list.
- Copied configs (Neovim, tmux, AeroSpace, greet.conf) are the user's after the first install; a config already at a guarded path skips the whole copy and says so.
- `nekoshell music` runs the first enabled plugin tagged `media`, or the `music_player` setting, in the current window; `--panel` opens it in the running terminal's panel instead (`--here` is kept for the hotkey panels the adapters write).
- p10k plugin: Powerlevel10k as the prompt in place of Starship, with a `~/.p10k.zsh` copied once and a colours file rendered per flavour; instant prompt is off when greet is enabled.
- omz plugin: oh-my-zsh's `git` and `web-search` plugins through antidote, without installing oh-my-zsh.
- yazi (file manager, theme rendered per flavour, `y` lands where you quit), gh (cached completions, delta as pager), mise (activated in every shell, copied-once config) and pure (a third prompt, conflicts with p10k) plugins.
- spotify search bar: `nekoshell spotify search [QUERY]` (alias `sps`) opens fzf over Spotify's results for the typed words, refilled as you type, and plays the pick on the active device; a numbered menu without fzf; an upstream parse error shows as one line.
- AI tool plugins: `ai` prints a welcome banner (tool, project, branch, last commit; templates of your own) in front of a tool; `claude-code` renders a Catppuccin custom theme and a status line for Claude Code and sets the two settings keys with the previous values restored on removal; `opencode` renders a theme for OpenCode and selects it in `tui.json`.
- Art providers: greet draws its sprite from any enabled plugin that ships a `greet-art` program. pokemon (the Pokémon, moved out of greet, in every profile), anime (anime-colorscripts' release tarball, checksummed), minecraft and colorscripts (pinned clones; only a vetted list of scripts runs). `ART` and `SPRITE_SHARE` in `greet.conf` pick among them, `nekoshell greet --art NAME` forces one, the doctor has a row per provider, and with none enabled the stats print alone.
- spotify rework: `app.toml` is copied once and is the user's, with `nekoshell spotify client-id` for a personal Spotify client id (the shared one is rate-limited at start-up), `nekoshell spotify login|logout` for the cached login, and `theme.toml` rendered per flavour with the `theme` line of `app.toml` pointed at it.
- The anime sprites are drawn at 30 percent of the pack's size, 10 rows instead of 32, so they sit level with the stats; `ANIME_SCALE` in greet.conf changes that.

### Five terminals

- Adapters for iTerm2, kitty, Ghostty, Warp and Apple Terminal.app, each behind the same ten functions: font, colours, a music panel, a background image where the terminal can draw one, a doctor block and a clean removal. Every colour comes from `core/theme/palettes.json`.
- `nekoshell terminal use a,b|all|installed` configures several terminals; the theme, the doctor, `terminal background` and uninstall walk the whole list, and the running terminal is the one the greeting draws in and the panel opens from.
- The core zshrc sources the running terminal's own hook (`terminals/<id>/zsh.zsh`); Ghostty's turns the quick terminal into the music panel.
- `nekoshell theme auto` follows the macOS appearance; each new shell re-resolves it in the background.

### Repository

- `actions/checkout` bumped to v7 in the workflows.
- One linter, `scripts/lint.sh` (shellcheck, shfmt, the repository shape rules, actionlint, yamllint, markdownlint), conventional commit messages checked by `scripts/check-commit-msg.sh`, git hooks installed by `make hooks`, and five required CI jobs: lint, test, install (once per terminal adapter), commits and secrets.
- `tests/core/repo.bats` guards the plugin and adapter contracts and keeps code off the v0.1 layout. Every shell file is formatted with `shfmt -i 2 -ci -bn`.
- Every commit carries a `Signed-off-by` trailer (`git commit -s`); the commit-msg hook and the `commits` job refuse one without it. `tests/core/commit-msg.bats` covers the checker.
- A fifth CI job, `secrets`, runs gitleaks over the whole history.
- `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CODEOWNERS`, issue forms for bugs, plugin requests and terminal adapter requests, and a `.gitattributes` that keeps development files out of the release tarball.
- Tests for the preflight in `install.sh` and `uninstall.sh`, the shape rules in `scripts/lint.sh`, the docs and profiles staying in step with `plugins/`, and one sweep that adds, checks and removes every plugin.
- `docs/ARCHITECTURE.md`, `docs/plugins/ARCHITECTURE.md`, `docs/contributing/` and `docs/ai/`; a root `CLAUDE.md` and `llms.txt`. The README leads with the Homebrew tap and the one-line installer.
- A release is one tag: `scripts/release.sh X.Y.Z` then `git push --follow-tags`. `release.yml` verifies the tag, runs the checks, attaches `nekoshell-X.Y.Z.tar.gz` and `SHA256SUMS` to a GitHub Release with the CHANGELOG section as notes, and rewrites the formula in the Homebrew tap from `packaging/homebrew/nekoshell.rb.tmpl`.
- `real-install.yml` brews the minimal profile on a macOS runner weekly.
- `docs/ci-checks/` describes every check and the release process.

### Install

- `bootstrap.sh`: `curl -fsSL .../bootstrap.sh | bash` clones or updates `~/.nekoshell` and runs the installer. `NEKOSHELL_REF` pins a tag.
- Under a Homebrew install the root is `opt/nekoshell/libexec`, not the versioned Cellar directory, so `brew upgrade` keeps every link valid. `nekoshell doctor` compares the recorded root by directory.

### Fixes

- A user's own `~/.config/starship.toml` or fastfetch config is backed up before the first render, and uninstall restores every backup set, not only the newest.
- A dry run records nothing: `--dry-run` and `--check` no longer leave the toml naming plugins or a theme that were never installed.
- A v0.1 machine is migrated: the recorded flavour is kept, the profile defaults to `full`, and the twelve stale links v0.1 left are swept.
- The zshrc sources iTerm2's shell integration, so the status bar's directory and git components fill in, and uninstall removes the iTerm2 dynamic profile.
- The greeting and `bin/nekoshell` resolve a link to a link, `help` and `version` create nothing in `$HOME`, and plugins are handed the flavour in force rather than mocha when nothing is recorded yet.

Verified on macOS 26 (Tahoe) with iTerm2, kitty, Ghostty, Warp and Terminal.app installed; see the terminal READMEs for the human steps each still needs.

## 0.1.0

The first version: an iTerm2-only rig installed by one script that stowed its configs into the home directory. It had the Catppuccin flavours switched by `nekoshell-theme`, the Pokémon greeting with fastfetch stats, the ⌥M Spotify panel as an iTerm2 hotkey window, fzf previews, atuin, Neovim and tmux configs copied once, opt-in AeroSpace, a Brewfile, a doctor and an uninstaller. v0.2 replaces its layout entirely; the installer migrates a v0.1 machine.
