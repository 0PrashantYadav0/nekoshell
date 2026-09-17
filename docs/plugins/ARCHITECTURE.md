# How a plugin works

A plugin is a directory under `plugins/` with a `plugin.toml` in it. Everything else is optional, and every optional file is picked up by name: `core/lib/plugin.sh` runs the hooks, the core zshrc sources the zsh files, `bin/nekoshell` finds the commands, and the greet plugin finds the art providers. There is no registry to edit.

`tests/fixtures/plugins/demo` is a working plugin carrying most of these: `install.sh`, `uninstall.sh`, `doctor.sh`, `plugin.zsh`, `late.zsh`, `antidote.txt`, `bin/`, `cmd/` and both file trees. Copy it to start.

## The directory

```text
plugins/<name>/
  plugin.toml        the nine keys, plus the optional copy_guard
  README.md          five headings; nekoshell plugin info prints it
  install.sh         on plugin add
  uninstall.sh       on plugin remove
  theme.sh           on plugin add and on every nekoshell theme
  doctor.sh          on nekoshell doctor, calling report
  early.zsh          sourced by the zshrc before anything prints
  plugin.zsh         sourced after the antidote bundle, before the prompt
  late.zsh           sourced after the prompt is set up
  antidote.txt       lines appended to the generated antidote bundle
  bin/               put on PATH by the zshrc
  cmd/<sub>.sh       becomes nekoshell <sub>
  greet-art          makes this plugin an art provider for the greeting
  greet-image        makes it an image provider: a picture, where the terminal draws them
  files/link/        symlinked into $HOME at the same relative path
  files/copy/        copied into $HOME once, then the user's
  files/*.tmpl       rendered by theme.sh; not linked or copied
```

A file directly under `files/` is not touched by `plugin_add`: only `files/link` and `files/copy` are trees it walks. That is where the `.tmpl` sources live, so `theme.sh` can render them wherever they belong.

## plugin.toml

The same flat TOML subset as `nekoshell.toml`: one key per line, arrays on one line, no escapes. The nine keys are all required, even when empty. `scripts/lint.sh` and `tests/core/repo.bats` both fail a plugin that is missing one.

| Key | Type | Meaning | Example |
| --- | --- | --- | --- |
| `name` | string | the directory's own name | `name = "btop"` |
| `summary` | string | one line, printed by `plugin list` and as the heading of `plugin add` | `summary = "A resource monitor that follows the theme, on top"` |
| `requires` | list | Homebrew formulas, installed before the files are linked | `requires = ["eza", "bat", "fd"]` |
| `casks` | list | Homebrew casks, installed after the formulas | `casks = ["aerospace"]` |
| `taps` | list | Homebrew taps, tapped before either | `taps = ["nikitabobko/tap"]` |
| `requires_plugins` | list | plugins enabled first, recursively | `requires_plugins = ["greet"]` |
| `terminals` | list | `["any"]`, or the adapter ids this plugin works in | `terminals = ["any"]` |
| `conflicts` | list | plugins that must not be enabled at the same time | `conflicts = ["pure"]` |
| `tags` | list | free words; `media` is the one the code reads | `tags = ["prompt", "shell"]` |
| `copy_guard` | list, optional | paths under `$HOME` whose presence skips the whole copy | `copy_guard = [".tmux.conf", ".config/tmux/tmux.conf"]` |

## What add does

`plugin_add NAME` in `core/lib/plugin.sh`, in order:

1. Fail when there is no `plugins/NAME/plugin.toml`.
2. Fail when `terminal_current` names a terminal and `terminals` lists neither it nor `any`.
3. Fail when any name in `conflicts` is already enabled.
4. For each name in `requires_plugins` that is not enabled, `plugin_add` it first. This recurses.
5. Print the summary as a heading.
6. `brew_tap` each entry in `taps`.
7. `brew_install` the `requires` formulas in one call, for whichever are missing. A failure stops here.
8. `brew_cask_install` the `casks` the same way.
9. `link_tree files/link $HOME`. A real file in the way is moved into the backup set first; a symlink already pointing at the same source is left alone.
10. For each `copy_guard` path that exists under `$HOME`, warn and set the copy aside. One guard path present skips the whole copy: half of a shipped Neovim config layered under an existing `init.lua` is worse than none of it, and the files stay readable in the checkout for anyone who wants to merge them by hand.
11. Unless a guard fired, `copy_once files/copy $HOME`. An existing file is reported as kept and never overwritten.
12. Run `install.sh`. A failure stops the add.
13. Stop here under `NEKOSHELL_DRY_RUN=1`. Everything above reports through `run`; everything below writes straight to disk.
14. Run `theme.sh`, so the rendered files exist in the flavour in force.
15. `config_list_add plugins NAME` in `~/.config/nekoshell/nekoshell.toml`.
16. `plugin_regen_antidote`: rewrite `~/.config/nekoshell/antidote.txt` as `core/antidote.txt` followed by each enabled plugin's `antidote.txt`, in the order they were enabled.
17. Print the plugin's `doctor.sh` rows. They are informational here: a row that fails does not undo the add.

## What remove does

`plugin_remove NAME [purge]`:

1. Fail when there is no such plugin. Warn and stop when it is not enabled.
2. Fail when another enabled plugin lists it in `requires_plugins`, naming that plugin.
3. Run `uninstall.sh`. A failure stops the removal.
4. `unlink_tree files/link $HOME`: remove the symlinks that point into this plugin's tree, and nothing else.
5. Stop here under a dry run.
6. `config_list_remove plugins NAME`, then regenerate the antidote bundle.
7. With `purge`, uninstall each formula in `requires` that no other enabled plugin lists, then each cask in `casks` the same way. The plugin has already left the enabled list, so it never counts itself.

Copied files stay. Rendered files stay unless the plugin's own `uninstall.sh` takes them back out. The closing line says so: `<name> removed (its copied configs are still yours)`.

## Hooks

`plugin_run_hook NAME HOOK` sources `plugins/NAME/HOOK.sh` in a subshell with `set -euo pipefail` and `plugin_env` applied, so every hook sees three variables:

| Variable | Value |
| --- | --- |
| `PLUGIN_NAME` | the plugin's directory name |
| `PLUGIN_DIR` | its absolute path |
| `FLAVOR` | the flavour in force, from `theme_current` |

The libraries are already sourced, so a hook can call `run`, `log_ok`, `theme_render_template`, `copy_once` and the rest. A hook that is not there is not an error.

`doctor.sh` is different in one way: it calls `report STATUS CHECK DETAIL`, which is defined by `core/cmd/doctor.sh` and inherited into the subshell. `STATUS` is `ok`, `warn` or `fail`; only a `fail` makes `nekoshell doctor` exit 1. A `doctor.sh` whose last command is a guarded check that is legitimately false would exit non-zero, so both `cmd_doctor` and `plugin_add` turn that into a `warn` row rather than letting it take the run down.

## Shell integration

The core zshrc reads the `plugins` list out of `nekoshell.toml` itself and sources, in this order:

- `early.zsh`, for every enabled plugin, before anything prints or loads. Powerlevel10k's instant prompt needs to be here.
- the antidote bundle, which is where each plugin's `antidote.txt` lines end up.
- `bin/` onto `PATH`, then `plugin.zsh`, for every enabled plugin.
- Starship, unless a `plugin.zsh` exported `NEKOSHELL_PROMPT` as something other than `starship`. The p10k and pure plugins do exactly that.
- `late.zsh`, for every enabled plugin.

Plugins load in the order they were enabled, which is the order `nekoshell.toml` records.

## Commands

`plugins/<name>/cmd/<sub>.sh` becomes `nekoshell <sub>`. The file defines `cmd_<sub>` and, by convention, `usage_<sub>`; nothing else may run when it is sourced. The file name is what makes the command, not the plugin name, so one plugin can provide several: the greet plugin ships `cmd/greet.sh` and `cmd/art.sh`.

`bin/nekoshell` looks in `core/cmd/` first, so a plugin cannot shadow a core command. `plugin_providing_cmd` then scans `plugins/*/cmd/<sub>.sh`. When the owner is enabled the dispatcher sets `PLUGIN_NAME`, `PLUGIN_DIR` and `FLAVOR`, sources the file and calls `cmd_<sub>`. When it is not, the message names `nekoshell plugin add <owner>` and the exit code is 2.

`nekoshell help` lists every core command with the second line of its file as the description, then every plugin `cmd/` file under "Plugin commands", marked `enabled` or `not enabled`. A plugin that is not enabled still appears there.

## Art providers

An executable `greet-art` at the top of the plugin makes it an art provider for the greeting. The file is the whole contract:

- Print the caption on the first line and the sprite on the lines after it.
- Print nothing and exit non-zero when there is nothing to draw. The greeting then shows the machine stats alone.
- List `greet` in `requires_plugins`.

`PLUGIN_NAME` and `PLUGIN_DIR` are set when it runs. Every shipped provider also seeds `RANDOM` from `NEKOSHELL_SEED` when that variable is in the environment, which is how a test pins the draw; the greet plugin's own doctor row sets it.

An executable `greet-image` makes the plugin an image provider instead: the caption on the first line, the path of a PNG or JPG on the second, and on an optional third line the size to draw at as `WIDTH HEIGHT` in cells (without it, `IMAGE_WIDTH` by `IMAGE_HEIGHT` from `greet.conf`, which the greeting exports). The greeting hands the file to fastfetch with the terminal's image flag, so an image provider is only drawn from where the terminal adapter lists `images` among its capabilities, and never on `--text`; where images cannot be drawn the other providers keep their odds. A plugin that ships both files is drawn as a picture where that works and as a sprite everywhere else.

The greeting picks among the enabled providers with `ART` from `~/.config/nekoshell/greet.conf`: `auto` gives each the same odds, and a list such as `pokemon:70,anime:30` weights them. A name that is not an enabled provider is dropped and a weight of 0 never draws.

The greeting runs on every new interactive shell, and its doctor warns above 150 ms. A provider that fetches over the network, or runs unpinned third-party code, does not belong here: `pokemon`, `minecraft` and `colorscripts` clone their packs in `install.sh` at a pinned commit and `anime` downloads the archive of a pinned commit and shrinks the pictures once, so drawing is a local read.

## Music players

`nekoshell music` finds its player through the `media` tag. With no argument it reads `music_player` from `nekoshell.toml`, defaulting to `auto`, and `auto` takes the first enabled plugin whose `tags` contain `media`, in the order the plugins were enabled.

The player itself is `plugins/<name>/bin/nekoshell-<name>`, an executable that runs the player in the current window. `spotify` is the one that ships: `tags = ["media"]` and `bin/nekoshell-spotify`. A player installed some other way is found on `PATH` under the same name. `--panel` hands that binary to `terminal_panel` instead of running it here.

## Writing one

Step by step, ending with a plugin that passes `make check`: [docs/contributing/writing-a-plugin.md](https://github.com/0PrashantYadav0/nekoshell/blob/main/docs/contributing/writing-a-plugin.md) in the repository (it is a contributor page, so it does not ship in the release tarball).
