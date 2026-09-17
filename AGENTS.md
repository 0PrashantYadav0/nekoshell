# Agent contract for nekoshell

Instructions to an AI agent installing nekoshell on a Mac or changing this repository. Follow the section that matches the task, in order.

## Installing

### 1. Preconditions

Run each check. If one fails, stop and report it; do not work around it.

```bash
uname -s               # must print Darwin
command -v brew        # must print a path
command -v zsh git     # both must print a path
```

If Homebrew is missing, hand the human this line and stop; do not run it yourself:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

The installer asks Homebrew for Starship, antidote and the JetBrainsMono Nerd Font itself, only for whichever is missing, so nothing else has to be installed by hand first.

### 2. Install

```bash
[ -d ~/.nekoshell ] || git clone https://github.com/0PrashantYadav0/nekoshell.git ~/.nekoshell
cd ~/.nekoshell && git pull --ff-only && ./install.sh --yes --profile full --terminal all
```

`--terminal all` configures every terminal that has an adapter (iTerm2, kitty, Ghostty, Warp, Terminal.app), whether or not the app is installed; `--terminal installed` configures only the ones whose app is present, and is the better choice when the human did not ask for a particular terminal. `--profile` is `minimal`, `dev` or `full`; with `--yes` and no `--profile` the installer picks `minimal`. Add `--with a,b` or `--without c` to adjust the list, and do not add `aerospace` unless the human asked for it: it taps a second Homebrew tap and needs an Accessibility grant only they can make.

The line is safe to run again: it updates an existing checkout, links nothing twice and backs up nothing it wrote itself. `./install.sh --check` prints what would change without changing anything.

### 3. Verify

```bash
nekoshell doctor --json
```

Exit code 0 is success. The output is a JSON array of `{"status", "check", "detail"}` rows; only a `fail` row makes the exit code 1, and its detail names the fix. `warn` rows are expected on a fresh machine and are for the human: `iterm2 prefs` (quit iTerm2, run `nekoshell terminal apply`), `terminal-app default` (quit and reopen Terminal.app), `ghostty hotkey` (Accessibility), `spotify login` (`nekoshell spotify login`), `spotify client id` (`nekoshell spotify client-id <id>`, needs a Spotify app the human registers), `greet time` (over its 150 ms budget; report the number). Do not proceed with a `fail` row present.

### 4. Hand off

Give the human the steps that apply, then stop. The installer prints them as well.

1. iTerm2: quit it, then run `nekoshell terminal apply` so the global preferences land.
2. Terminal.app: quit and reopen it.
3. Ghostty: System Settings, Privacy & Security, Accessibility, turn Ghostty on; then restart Ghostty once.
4. Warp: sign in.
5. Run `nekoshell spotify login` (needs Spotify Premium), and register a Spotify app for `nekoshell spotify client-id <id>`.
6. Run `tmux` and press `C-a I` once to fetch the tmux plugins. Do not start a tmux session yourself.
7. Open `nvim` once so lazy.nvim fetches its plugins.

### 5. Undo

The installer moves every file it replaces into `~/.local/share/nekoshell/backup/<timestamp>/`, each set with a `manifest.txt`. Never delete that directory. `./uninstall.sh --yes` removes the plugins, unlinks the zshrc, restores every backup set and takes nekoshell's config out of every configured terminal; `--purge` also uninstalls the Homebrew formulas no other plugin needs. [docs/INSTALL.md](docs/INSTALL.md) lists what it leaves in place.

## Extending

### Adding a plugin

`tests/fixtures/plugins/demo` is a working plugin with one of everything; copy it to `plugins/<name>/`. A plugin is a directory with:

- `plugin.toml`, with the nine keys `tests/core/repo.bats` requires, every one present even when empty: `name`, `summary`, `requires` (Homebrew formulas), `casks`, `taps`, `requires_plugins` (enabled first), `terminals` (`["any"]` or adapter ids), `conflicts`, `tags` (`media` is what `nekoshell music` looks for). `copy_guard` is optional: paths under `$HOME` whose presence skips the whole copy.
- Hooks, each optional, run by `core/lib/plugin.sh` with `PLUGIN_NAME`, `PLUGIN_DIR` and `FLAVOR` set: `install.sh` and `uninstall.sh` on add and remove, `theme.sh` on every theme switch, `doctor.sh` reporting rows with `report ok|warn|fail "check" "detail"`.
- `files/link/`, symlinked into `$HOME`, and `files/copy/`, copied once and then the user's.
- `early.zsh`, `plugin.zsh` and `late.zsh`, sourced by the core zshrc first of all (before anything prints), before the prompt, and after it; a plugin.zsh that sets `NEKOSHELL_PROMPT` takes the prompt over from Starship; `antidote.txt`, zsh plugins appended to the generated bundle; `bin/`, put on `PATH`; `cmd/<name>.sh`, defining `cmd_<name>` and `usage_<name>`, which becomes `nekoshell <name>`.
- `greet-art`, an executable that prints a caption line and then a sprite (exit non-zero, silent, when it has nothing), makes the plugin an art provider for the greeting; `greet-image`, an executable that prints a caption line, the path of a PNG or JPG, and optionally a `WIDTH HEIGHT` line in cells, makes it an image provider, drawn only where the terminal adapter lists `images`. Either must list `greet` in `requires_plugins`, fetch its pack in `install.sh` pinned, and answer in a few milliseconds.
- `README.md` with exactly these headings: `## What it does`, `## Installs`, `## Files`, `## After install`, `## Remove`. The installer prints the "After install" section at the end of a run.
- A user page, `docs/plugins/<name>.md`, with the headings `## What you get`, `## Using it`, `## Files`, `## Theme`, `## Turning it off`, and a row in the table in [docs/plugins/README.md](docs/plugins/README.md). Facts from the code only: no key or flag that is not in a config or a script.

Add `tests/plugins/<name>.bats`, and a fake under `tests/fakes/` for any tool the hooks call.

### Adding a terminal adapter

`terminals/adapter.sh` is the contract; `terminals/<id>/adapter.sh` is sourced after it and must define all ten functions itself, even the ones it leaves at the default: `terminal_name`, `terminal_detect` (0 when the shell runs in it), `terminal_installed`, `terminal_capabilities` (words from `truecolor images background panel hotkey`), `terminal_font_name`, `terminal_apply FLAVOR`, `terminal_background PATH|none [OPACITY]`, `terminal_panel CMD...`, `terminal_remove` and `terminal_doctor`. Colours go through `theme_render_template` from a `.tmpl` beside the adapter. `terminal_detect_env` in `core/lib/terminal.sh` and the core zshrc both need to know the environment variable that identifies the terminal. A `zsh.zsh` beside the adapter is sourced by the core zshrc inside that terminal.

Write `terminals/<id>/README.md` with `## What it configures`, `## Panel`, `## Images`, `## Uninstall` and `## Known limits`, add `tests/terminals/<id>.bats`, and add the id to the `install` matrix in `.github/workflows/ci.yml`.

### Checks

`make tools` installs the linters and bats; `make hooks` installs the git hooks (pre-commit lints the staged files, commit-msg checks the message, pre-push runs the suite). `make check` is what CI runs: `scripts/lint.sh` (shellcheck, shfmt with `-i 2 -ci -bn`, the repository shape rules, actionlint, yamllint, markdownlint) and `bats -r tests`. `scripts/lint.sh --fix` rewrites the shell files with shfmt.

Commit messages follow `scripts/check-commit-msg.sh`: a conventional subject `type(scope): description` with the type one of feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert, a lower-case description, no trailing full stop, 72 characters at most, a blank second line, a `Signed-off-by: Name <email>` trailer (`git commit -s`), and a trailer of the form `Co-Authored-By: Name <email>` when an AI assistant wrote it. Pull requests run five required jobs: lint, test, install (once per terminal adapter), commits and secrets.

### Never

- Edit a rendered file by hand (`~/.config/starship.toml`, `~/.config/nekoshell/theme.zsh`, `~/.config/fastfetch/config.jsonc`, a terminal's `nekoshell` config file). Change the template and re-run `nekoshell theme`.
- Write a colour anywhere but `core/theme/palettes.json`. Everything that carries colour is rendered from it.
- Add a copyrighted image. The art pack samples are the project's own pixel art; the sprites come from the provider plugins' packs at greeting time.
- Add an art provider whose draw takes more than a few milliseconds, or one that runs unpinned third-party code: the greeting has a 150 ms budget and runs on every shell.
- Merge a shipped Neovim, tmux or AeroSpace config into one the human already has. The installer skips the copy and says so; the human decides.
- Run `defaults write` for iTerm2 while it is running, install anything with sudo, or commit on the human's behalf.
