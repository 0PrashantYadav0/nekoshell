# Architecture

nekoshell is one command. `bin/nekoshell` resolves its own path back to the checkout, sources every library in `core/lib`, and hands the first argument to a subcommand: `core/cmd/<sub>.sh` when core provides it, otherwise the `cmd/<sub>.sh` of the plugin that does. A subcommand file defines `cmd_<sub>` and `usage_<sub>` and nothing else runs on source.

The libraries under `core/lib` only define functions. Nothing there touches the disk when it is sourced, so a hook, a test or a plugin can source one and use a single function. Everything that writes lives in `core/cmd`, in a plugin hook, or in a terminal adapter. Two paths are fixed: the checkout, which the user owns and `git pull`s, and `$HOME`, where nekoshell links, copies and renders files and keeps a record of every original it moved out of the way.

## The tree

| Path | What is in it |
| --- | --- |
| `bin/` | `nekoshell`, plus five v0.1 shims (`nekoshell-greet` and friends) that exec `nekoshell <sub>` |
| `core/cmd/` | one file per core subcommand: doctor, help, install, music, plugin, terminal, theme, uninstall, version |
| `core/lib/` | the libraries, function definitions only |
| `core/zsh/` | `.zshrc` and the two files under `.config/nekoshell/zsh/`, linked into `$HOME` |
| `core/theme/` | `palettes.json`, `gen-palettes.py` that generates it, `render.py` that substitutes it |
| `core/starship/` | `starship.toml.tmpl`, the prompt |
| `core/antidote.txt` | the zsh plugins every install gets, before any plugin adds its own |
| `terminals/` | `adapter.sh`, the contract, and one directory per adapter: ghostty, iterm2, kitty, terminal-app, warp |
| `plugins/` | 24 plugins, one directory each |
| `profiles/` | `minimal.txt`, `dev.txt`, `full.txt`: plugin names, one per line |
| `data/` | vendored files, currently the zsh-syntax-highlighting Catppuccin themes |
| `docs/` | the manual: `README.md` (the index), `INSTALL.md`, `CONFIGURATION.md`, `TERMINALS.md`, this file, `DISTRIBUTION.md`, `REMOTE.md` and `plugins/`, plus the contributor-only `contributing/`, `ci-checks/`, `ai/`, `superpowers/`, `screenshots/` and `assets/` |
| `skills/nekoshell/` | `SKILL.md`, the Claude Code skill |
| `packaging/` | `homebrew/nekoshell.rb.tmpl`, the only copy of the formula |
| `scripts/` | `lint.sh`, `check-commit-msg.sh`, and the release scripts `package.sh`, `release.sh`, `changelog-section.sh`, `render-formula.sh` |
| `tests/` | the bats suite, its helpers, fakes and fixtures |
| `install.sh`, `uninstall.sh` | check macOS and Homebrew, then `exec bin/nekoshell install`/`uninstall` with the flags |
| `bootstrap.sh`, `VERSION` | the one-line installer's download-verify-unpack-and-run (a git checkout for a branch ref), and the version the release is cut from |

A release tarball is `git archive` of the tag, so the tree above is not all of it: everything only a contributor or the repository page opens is `export-ignore` in `.gitattributes` and stripped from the tarball. That is `tests/`, `scripts/`, `skills/`, `packaging/`, `Makefile`, `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `llms.txt`, the dot-files, and the six contributor-only directories under `docs/`. A new development-only path needs its own `export-ignore` line, and a page that ships must not link into a path that does not: the link becomes a `https://github.com/0PrashantYadav0/nekoshell/blob/main/<path>` URL instead. [DISTRIBUTION.md](DISTRIBUTION.md) has the tarball itself.

## The dispatcher

`bin/nekoshell` starts by finding the checkout. It follows `$BASH_SOURCE` through every symlink, up to 16 hops, resolving a relative target against the link's own directory rather than `$PWD`, and sets `NEKOSHELL_ROOT` to the parent of the directory it lands in. A shim in `~/.local/bin` pointing at a link pointing at the checkout is two hops, and stopping after one would compute a root that does not exist.

It then sources the libraries in a fixed order, because each one uses the one before it:

```text
log paths backup config link brew terminal plugin theme zsh_migrate
```

The first argument is the subcommand; with none it is `help`. `-h` and `--help` become `help`, `-v` and `--version` become `version`. Every subcommand except those two creates `$NEKOSHELL_CONFIG`, `$NEKOSHELL_CACHE` and `$NEKOSHELL_DATA` first: the libraries have no side effects on source, so the dispatcher is what bootstraps the directories hooks assume exist. Asking what nekoshell is must not leave three directories in `$HOME`, so help and version skip it.

A name containing a `/` is rejected before any lookup. Core command files and plugin `cmd/` files are both single path segments, so a slash can only be an attempt to walk out of those directories.

Resolution is core first. If `core/cmd/$sub.sh` exists it is sourced and `cmd_$sub` runs. Otherwise `plugin_providing_cmd` scans `plugins/*/cmd/$sub.sh` for an owner. An owner that is enabled gets `plugin_env` called (so `PLUGIN_NAME`, `PLUGIN_DIR` and `FLAVOR` are set), its file sourced and `cmd_$sub` run. An owner that is not enabled gets a message naming `nekoshell plugin add <owner>` and exit 2. An unknown name prints the help to stderr and exits 2.

## Libraries

| File | What it owns | Main functions | Needs |
| --- | --- | --- | --- |
| `log.sh` | the printing helpers and `run` | `log_info`, `log_ok`, `log_warn`, `log_fail`, `log_step`, `log_head`, `run`, `run_quiet`, `confirm` | nothing |
| `paths.sh` | the well-known paths | none; sets `NEKOSHELL_CONFIG`, `NEKOSHELL_CACHE`, `NEKOSHELL_DATA`, `NEKOSHELL_BACKUP_ROOT`, `NEKOSHELL_TOML`, `NEKOSHELL_ROOT` | nothing |
| `backup.sh` | the timestamped backup sets and restoring them | `backup_begin`, `backup_path`, `backup_restore_all`, `backup_link_target`, `backup_link_target_lexical`, `backup_root_inside_checkout` | log, paths |
| `config.sh` | the flat TOML subset both `nekoshell.toml` and `plugin.toml` are written in | `toml_get`, `toml_list`, `toml_set`, `toml_set_list`, `config_get`, `config_set`, `config_has`, `config_list`, `config_list_add`, `config_list_remove` | paths |
| `link.sh` | mirroring a directory into `$HOME` | `link_tree`, `unlink_tree`, `copy_once` | paths, log, backup |
| `brew.sh` | Homebrew, every call a no-op for what is present | `brew_has`, `brew_cask_has`, `brew_install`, `brew_cask_install`, `brew_tap` | log |
| `terminal.sh` | finding and loading adapters | `terminal_all`, `terminal_detect_env`, `terminal_load`, `terminal_configured_all`, `terminal_current`, `terminal_installed_all`, `terminal_expand_ids`, `terminal_configure` | paths, log, config |
| `plugin.sh` | discovery, enable, disable | `plugin_all`, `plugin_meta`, `plugin_meta_list`, `plugin_enabled`, `plugin_env`, `plugin_run_hook`, `plugin_regen_antidote`, `plugin_providing_cmd`, `plugin_add`, `plugin_remove` | paths, log, backup, config, link, brew, terminal |
| `theme.sh` | the flavours and every render | `theme_flavors`, `theme_hexes`, `theme_render_template`, `theme_write_zsh`, `theme_setting`, `theme_resolve`, `theme_current`, `theme_apply`, `theme_backup_foreign` | paths; log for the renders; config, terminal and plugin for `theme_apply` |
| `zsh_migrate.sh` | lifting aliases and exports out of an old `.zshrc` | `zsh_migrate_aliases` | nothing |

The TOML subset is deliberately small: `key = "string"`, `key = ["a", "b"]`, `key = bare`, `#` comments, one key per line, arrays on one line, no escapes. That is all `nekoshell.toml` and every `plugin.toml` use, and it is why the zshrc can read the file without starting a process.

## State on the machine

Everything is under `$HOME`, so a test can redirect `HOME` and touch nothing real.

| Path | What it is |
| --- | --- |
| `~/.config/nekoshell/nekoshell.toml` | the settings, written by the installer and read by everything |
| `~/.config/nekoshell/theme.zsh` | generated by `theme_write_zsh` on every theme switch |
| `~/.config/nekoshell/antidote.txt` | generated by `plugin_regen_antidote`: `core/antidote.txt` plus each enabled plugin's |
| `~/.config/nekoshell/zsh/aliases.zsh`, `zsh/env.zsh` | symlinks into `core/zsh/.config/nekoshell/zsh/` |
| `~/.config/nekoshell/zsh/local.zsh` | yours, sourced last, never overwritten; the installer migrates old aliases into it |
| `~/.config/starship.toml` | rendered from `core/starship/starship.toml.tmpl` |
| `~/.zshrc` | a symlink to `core/zsh/.zshrc` |
| `~/.cache/nekoshell` | created by the dispatcher; plugins use it for their own caches |
| `~/.local/share/nekoshell/backup/<timestamp>/` | one set per install or `plugin add`, plus `manifest.txt` |

The keys core reads and writes in `nekoshell.toml`. Terminal adapters record a few of their own beside them: ghostty and kitty write `background` and `background_opacity`, and terminal-app writes `terminal_app_previous_default`.

| Key | Written by | Meaning |
| --- | --- | --- |
| `root` | `cmd_install` | the checkout; the doctor fails when it does not match |
| `terminal` | `cmd_install`, `terminal_configure` | the primary terminal, for a shell in none of the configured ones |
| `terminals` | `cmd_install`, `config_list_add` in `terminal_configure` | every configured terminal |
| `theme` | `cmd_install`, `cmd_theme` | `auto` or a flavour |
| `theme_resolved` | `theme_apply` | the flavour the last render actually used |
| `theme_auto_dark`, `theme_auto_light` | nothing; read by `theme_resolve` | what `auto` maps dark and light to, defaulting to mocha and latte |
| `profile` | `cmd_install` | the profile that run used |
| `plugins` | `plugin_add`, `plugin_remove` | the enabled plugins, in the order they were enabled |
| `music_player` | nothing; read by `cmd_music` | which player `nekoshell music` runs |

A linked file lives in the checkout: `link_tree` makes `$HOME/<relative>` a symlink to `<src>/<relative>`, so editing it edits the repository copy and `git pull` changes it. A copied file is written once by `copy_once` and then belongs to the user: an existing file is reported as kept and never touched again. A rendered file is written from a `.tmpl` and overwritten on the next theme switch.

Anything real that stands where a link or a render is about to go is moved first. `backup_path` moves `$HOME/<rel>` into `$NEKOSHELL_BACKUP_DIR/<rel>` and appends the relative path to that set's `manifest.txt`. A symlink already pointing into the checkout is left alone, which is what makes a second install back up nothing new. `backup_restore_all` walks the sets newest first and only moves an entry back when the set still holds a source, so an older set cannot overwrite a newer original; a restored set's manifest is renamed to `manifest.restored`.

## The shell

`~/.zshrc` is a symlink to `core/zsh/.zshrc`, so the file the shell reads is the file in the repository.

It derives its own root from its path, `${${(%):-%x}:A:h:h:h}`, and puts `$NEKOSHELL_ROOT/bin` and `~/.local/bin` on `PATH`. It then reads `nekoshell.toml` with zsh's own parameter expansion, in an anonymous function with `extended_glob` local to it, pulling out the `plugins` list and the `theme` value. No process is started, so the shell does not pay for a parse.

The order after that is fixed:

1. Every enabled plugin's `early.zsh`, before anything prints. Powerlevel10k's instant prompt has to be sourced here.
2. `nekoshell theme --resolve` in the background when `theme` is `auto`, so the prompt is not delayed; the next shell sees the change.
3. `~/.config/nekoshell/zsh/env.zsh`, then `~/.config/nekoshell/theme.zsh`.
4. The running terminal's `terminals/<id>/zsh.zsh`, when the adapter ships one. Detection repeats `terminal_detect_env`'s tests inline, again with no process.
5. History, `compinit`, the completion matcher.
6. antidote from `$HOMEBREW_PREFIX/opt/antidote/share/antidote/antidote.zsh` (or `/opt/homebrew` and `/usr/local` in turn), loading `~/.config/nekoshell/antidote.txt`.
7. `~/.config/nekoshell/zsh/aliases.zsh`.
8. Each enabled plugin's `bin/` onto `PATH`, then its `plugin.zsh`.
9. Starship, unless a `plugin.zsh` set `NEKOSHELL_PROMPT` to something else. The p10k and pure plugins do.
10. iTerm2's own shell integration, only inside iTerm2.
11. Each enabled plugin's `late.zsh`.
12. `~/.config/nekoshell/zsh/local.zsh`, which is yours.

## Plugins

Everything past the shell and the prompt is a plugin: a directory under `plugins/` with a `plugin.toml` and whatever hooks, files and commands it needs. `plugin_add` installs its taps, formulas and casks, links and copies its files, runs its hooks, records it in `nekoshell.toml` and regenerates the antidote bundle; `plugin_remove` undoes that.

How a plugin is built, key by key and hook by hook: [plugins/ARCHITECTURE.md](plugins/ARCHITECTURE.md). What each one does for a user: [plugins/README.md](plugins/README.md).

## Terminal adapters

`terminals/adapter.sh` is the contract. `terminal_load ID` sources it and then `terminals/<id>/adapter.sh`, always taking the contract from the checkout so only the adapters vary. An adapter defines all ten functions, even the ones it leaves at the default; `scripts/lint.sh` and `tests/core/repo.bats` both check that.

| Function | What it must do |
| --- | --- |
| `terminal_name` | print the id |
| `terminal_detect` | status 0 when this shell runs in it |
| `terminal_installed` | status 0 when the app is on this Mac |
| `terminal_capabilities` | words from `truecolor images background panel hotkey` |
| `terminal_font_name` | the Nerd Font, spelled the way this terminal's config wants it |
| `terminal_apply FLAVOR` | write the font and the colours into the terminal's config |
| `terminal_background PATH\|none [OPACITY]` | set or clear a background image |
| `terminal_panel CMD...` | run `CMD` in the terminal's panel or overlay |
| `terminal_remove` | take back what `terminal_apply` wrote |
| `terminal_doctor` | call `report status check detail` for its own rows |

The default `terminal_panel` is `terminal_panel_default`: a `tmux display-popup` inside tmux, and the command in this window outside it. An adapter that overrides `terminal_panel` can still call `terminal_panel_default` for the half it does not replace.

Two questions about terminals have different answers. `terminal_configured_all` is which terminals this machine configures: the `terminals` list, falling back to the single `terminal` key. `theme_apply`, the doctor and uninstall walk that list in full. `terminal_current` is which terminal this shell is in: the running one whenever it has an adapter, so the greeting and the panel act on the window in front of the user, and only then the `terminal` key, the first configured one, or the environment.

`terminal_detect_env` reads the environment only: `KITTY_WINDOW_ID` or `TERM=xterm-kitty`, `GHOSTTY_RESOURCES_DIR` or `TERM_PROGRAM=ghostty`, `WEZTERM_EXECUTABLE` or `TERM_PROGRAM=WezTerm`, then `TERM_PROGRAM` of `iTerm.app`, `Apple_Terminal` or `WarpTerminal`. It names wezterm, which has no adapter in this repository; `terminal_current` checks `terminal_has_adapter` before trusting a detection, so that costs nothing.

Each adapter's own `terminals/<id>/README.md` says exactly what it writes and what it cannot do.

## Themes

`core/theme/palettes.json` holds the four Catppuccin flavours (latte, frappe, macchiato, mocha), each mapping 42 role names to a hex string with no leading `#`: Catppuccin's 26 design roles (`rosewater` to `crust`), then the 16 ANSI terminal colours from upstream's `ansiColors` block as `ansiblack`, `ansired` ... `ansiwhite` and `ansibrblack` ... `ansibrwhite`. The ANSI block is per flavour: the dark flavours draw black as `surface1`, latte as `subtext1`, a dark grey, so black text stays readable on the light base, and every flavour has its own bright shades. The terminal templates and the iTerm2 and Terminal.app profile builders take ANSI 0 to 15 from those roles and nothing else. It is generated by `core/theme/gen-palettes.py` from catppuccin/palette at a commit pinned in the script, and it is the only place in the repository a colour is written down.

Anything that carries colour is a `.tmpl` rendered through `theme_render_template`, which runs `core/theme/render.py`. The placeholders are `@@FLAVOR@@`, `@@TITLE@@`, `@@hex:ROLE@@`, `@@HEX:ROLE@@` (with the `#`), `@@sgr:ROLE@@` (an SGR truecolor triple) and `@@rgb:ROLE@@`. render.py builds the file in memory and renames it into place, so a bad placeholder or a full disk cannot leave half a config behind.

`theme_setting` is what `nekoshell.toml` records, which may be `auto`. `theme_resolve` turns `auto` into a flavour by reading `defaults read -g AppleInterfaceStyle`, mapping dark and light through `theme_auto_dark` and `theme_auto_light`. `theme_current` prefers the recorded `theme_resolved`, which is what the last render actually used.

`theme_apply FLAVOR` does the whole switch, in this order: clear a stale link at `~/.config/starship.toml` and back up a foreign file there, render the starship prompt, write `~/.config/nekoshell/theme.zsh`, record `theme_resolved`, call `terminal_apply` for every configured terminal, then run every enabled plugin's `theme.sh`. A terminal or plugin hook that fails warns and the switch continues: neither may take the prompt and the shell colours down with it. A dry run reports and writes nothing, because every step below the gate writes straight to disk rather than through `run`.

`theme_is_rendered` is how a file nekoshell wrote is told from one the user wrote: the header of a rendered file names nekoshell in its first ten lines. `theme_backup_foreign` moves a user's own file into the backup set exactly once, because the render that follows leaves one of ours in its place.

## The installer

`install.sh` checks for macOS and Homebrew and execs `bin/nekoshell install "$@"`, so `nekoshell install --yes --profile full --terminal all` and `./install.sh --yes --profile full --terminal all` are the same run.

Before the numbered steps there is a preflight, skippable with `NEKOSHELL_SKIP_PREFLIGHT`: Darwin, `brew`, `zsh`, `git`. Then seven steps, as `log_step` prints them:

1. **Terminal.** `--terminal` wins, expanded by `terminal_expand_ids` (`all`, `installed`, ids comma-separated or not). Without it, `terminal_detect_env` first, then each adapter's own `terminal_detect`. With neither and a tty, a `select` from the installed ones.
2. **Profile.** `--profile`, else `full` on a machine upgrading from v0.1, else a `select` of minimal, dev, full and pick on a tty, else minimal. `--with` adds names and `--without` drops them; a name that is not a plugin stops the run.
3. **Confirm.** Skipped by `--yes` and `--check`.
4. **Backup and core.** Refuses to run when the backup root would land inside the checkout. Begins a backup set, drops v0.1's `theme` and `root` marker files, migrates aliases out of an existing `~/.zshrc` into `~/.config/nekoshell/zsh/local.zsh` and backs the original up, sweeps the v0.1 stow links, links `core/zsh` into `$HOME`, asks Homebrew for starship and antidote (a failure stops the run) and for the `font-jetbrains-mono-nerd-font` cask (a failure only warns), then writes `root`, `terminal`, `terminals`, `theme`, `profile` and an empty `plugins` list into `nekoshell.toml`.
5. **Theme.** Backs up a foreign `~/.config/starship.toml` and `~/.config/fastfetch/config.jsonc`, then `theme_apply "$(theme_resolve)"`.
6. **Plugins.** `plugin_add` for each chosen plugin, in order. A failure stops and says that re-running install continues.
7. **Doctor and next steps.** Runs `cmd_doctor`, then prints each enabled plugin's `## After install` section from its README.

`--dry-run` sets `NEKOSHELL_DRY_RUN=1`, which `run`, `link_tree`, `copy_once`, `theme_apply` and `plugin_add` all honour. `--check` implies it. Under a dry run steps 4 to 6 report what they would do, the toml is not written, no plugin is recorded and step 7 prints one line instead of the doctor.

The v0.1 sweep is a fixed list of HOME-relative paths that v0.1 kept as stow links. A link at one of them is removed when it is broken or still resolves into `<root>/stow/`. A link v0.2 wrote resolves into `core/` or `plugins/` and is left where it is, so the sweep is safe on a machine that was never on v0.1.

## Doctor

`nekoshell doctor` prints one row per check and exits 1 only when a row is a `fail`. Rows are `status`, `check`, `detail`, printed as `%-4s %-28s %s`. `--json` prints the same rows as a JSON array of `{"status", "check", "detail"}` objects instead. `--plugin NAME` runs one plugin's block and nothing else.

`report` is defined in `core/cmd/doctor.sh` and appends a tab-separated row to a temp file. It is a file rather than an array because plugin hooks run inside `plugin_run_hook`'s subshell, whose variables never reach back out. Tabs and newlines in the detail are flattened to spaces first. Adapters and plugin `doctor.sh` hooks call `report` directly, so there is exactly one row format.

A full run is the core block (homebrew, zshrc, config, starship, the zsh plugin manager, the font and its glyphs, theme, antidote), then one block per configured terminal, then one per enabled plugin. The font glyph check parses the TrueType `cmap` table in Python and looks for U+F00BA: present is `ok`, absent is `fail`, unparseable is `warn`. A hook that exits non-zero on a guarded, legitimately-false last check produces a `warn` row rather than taking the rest of the doctor down under `set -e`.

## Tests

`bats -r tests` is the whole suite: `tests/core` for the libraries and the dispatcher, `tests/plugins/<name>.bats` for each plugin, `tests/terminals/<id>.bats` for each adapter. `tests/helpers.bash` gives every test a throwaway `HOME`, `tests/fakes` stands in for the tools an install would otherwise run, and `tests/fixtures` holds sample plugins and adapters. No test touches the real `HOME`, runs a real `brew`, or writes into the checkout.

How to write one: [docs/contributing/testing.md](https://github.com/0PrashantYadav0/nekoshell/blob/main/docs/contributing/testing.md) in the repository (it is a contributor page, so it does not ship in the release tarball).
