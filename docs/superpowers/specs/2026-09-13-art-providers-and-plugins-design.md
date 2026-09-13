# Art providers, four list plugins, AI tool plugins, Spotify search

Design for the next round of nekoshell plugins, agreed on 2026-09-13. Four
independent pieces, each its own pull request, in this order:

1. The greeting becomes an engine with **art providers**: `pokemon` (the
   default), `anime`, `minecraft` and `colorscripts` as plugins.
2. Four plugins from the terminals-are-sexy list: `yazi`, `gh`, `mise`, `pure`.
3. AI tool plugins: a shared `ai` base, `claude-code` and `opencode`.
4. A search bar for the `spotify` plugin.

Everything follows the existing plugin contract (AGENTS.md): nine
`plugin.toml` keys, the five README sections, hooks, bats tests with fakes in a
throwaway HOME, a page under `docs/plugins/`, lint clean.

## 1. Art providers

### Today

`greet` does three jobs: it installs fastfetch and renders its config, it
clones pokemon-colorscripts and draws a Pokémon, and it draws a picture from
the user's art pack when the terminal can show images. The Pokémon is wired in:
`show_pokemon`, `pokemon_facts`, `data/pokemon.tsv`, `SHINY_ODDS`,
`GENERATIONS` and `POKEMON_SHARE` all live in greet.

### The seam

A plugin is an **art provider** when it ships an executable `greet-art` in
its directory. The interface is one process:

- Input: the environment every plugin script gets (`PLUGIN_DIR`,
  `NEKOSHELL_CONFIG`, `NEKOSHELL_CACHE`, `NEKOSHELL_SEED`), plus
  `~/.config/nekoshell/greet.conf` already sourced, so a provider reads its
  own keys from it (`POKEMON_SHINY_ODDS`, `ANIME_ONLY`, ...). Keys are
  prefixed with the provider's name in upper case.
- Output: line 1 is the caption for fastfetch's "Art" row
  (`Pikachu · #025 · Electric · Gen 1`), the rest is the sprite as ANSI text.
- Exit: 0 with output, or non-zero and silent when it has nothing to draw
  (not installed, empty pack). It never prompts and never writes outside
  `NEKOSHELL_CACHE`.
- Budget: the whole greeting stays under the 150 ms the doctor measures, so a
  provider is a shell script that picks and prints a file, not a python
  program.

`nekoshell-greet` (the engine) does the rest:

- Providers are the enabled plugins, in enabled order, that have `greet-art`.
- `greet.conf` gains `ART=auto` (a random enabled provider, equal odds) or a
  weighted list `ART=pokemon:70,anime:30`; a name that is not enabled is
  skipped with no message. `POKEMON_SHARE` is renamed `SPRITE_SHARE` (the
  percentage of launches that draw a sprite rather than an image from the art
  pack, on terminals that can draw images); the old key is still read.
- With no provider and no image, the stats are still printed with
  `--logo none`, so a bare `greet` is a greeting.
- `nekoshell greet --art NAME` forces one provider; `--text` and `--image`
  keep their meaning.
- The doctor gets one row per enabled provider (`art: pokemon ok`) and warns
  `no art provider enabled (run: nekoshell plugin add pokemon)` when the list
  is empty.

`greet` keeps: fastfetch, the rendered config, `greet.conf`, the art pack and
`nekoshell art`, `late.zsh`, the silence rules, the budget. It no longer
clones anything.

### The providers

| Plugin | Source | Pinned to | Install | Caption |
| --- | --- | --- | --- | --- |
| `pokemon` | gitlab phoneybadger/pokemon-colorscripts (moved out of greet unchanged) | commit `5802ff6` | git clone into `~/.local/share/pokemon-colorscripts` | name, number, type, generation from `data/pokemon.tsv`; shiny 1 in `POKEMON_SHINY_ODDS`; `POKEMON_GENERATIONS` |
| `anime` | github juanlouisr/anime-colorscripts, MIT | release v1.1.3 tarball, sha256 recorded | curl the tarball into `~/.local/share/anime-colorscripts` (the git tree holds no sprites; the build scrapes the web) | file name prettified (`Hatsune Miku`); `ANIME_ONLY="miku naruto"` restricts to names containing a word |
| `minecraft` | github Axistorm1/minecraft-colorscripts, MIT | commit `e7186dd` | git clone into `~/.local/share/minecraft-colorscripts` | block name from `colorscripts/default-1.8.9/NAME.txt` |
| `colorscripts` | github theamallalgi/colorscripts, MIT | commit `7a87797` | git clone into `~/.local/share/colorscripts` | script name; these are ANSI patterns in the terminal's own palette, so they follow the flavour for free |

Each provider draws the file itself (`cat` after a random pick with
`$RANDOM`, seeded by `NEKOSHELL_SEED`); the upstream launcher scripts are not
used, because the anime one needs GNU coreutils on macOS and none of them is
needed to pick a file. All four have `requires_plugins = ["greet"]`,
`tags = ["look"]`, an `install.sh` that fetches and pins (warning, never
failing, offline), a `doctor.sh` with one row that proves a draw works, and
`uninstall.sh` that leaves the fetched data in place (as greet does today;
`--purge` removes it).

Considered and left out: ponysay (Homebrew formula, but a python start-up
that alone spends the 150 ms budget) and krabby (not in Homebrew; Pokémon
again).

### Default

`pokemon` joins the `minimal`, `dev` and `full` profiles right after `greet`,
so an installation shows Pokémon unless asked otherwise; the other three are
added by hand (`nekoshell plugin add anime`). The install picker lists them
like any plugin. A machine that already has greet enabled and the Pokémon
checkout in place gets `pokemon` enabled by greet's install hook the next
time `nekoshell install` runs, so nothing changes for it.

### Tests

The greet suite splits: the clone and pin tests move to `pokemon.bats` with
the existing git and pokemon-colorscripts fakes; `greet.bats` gains a fixture
provider under `tests/fixtures/plugins/fakeart/greet-art` and tests the
selection (auto, weighted, forced, none), the `--logo none` path and the old
`POKEMON_SHARE` key. `anime.bats` uses the `curl` fake with a tiny tarball
built in `setup`. `repo.bats` learns the contract: a `greet-art` file is
executable and its plugin requires greet.

## 2. From terminals-are-sexy

| Plugin | Homebrew | Owned files | Shell | Theme |
| --- | --- | --- | --- | --- |
| `yazi` | `yazi` (plus `ffmpeg`, `poppler`, `resvg`, `imagemagick` for previews are left to the user; `fd`, `rg`, `fzf`, `zoxide` come from plugins already) | `~/.config/yazi/yazi.toml` copied once, `copy_guard`; `~/.config/yazi/theme.toml` rendered | `y` function that changes directory to where yazi quit | `files/theme.toml.tmpl` derived from yazi-rs/flavors catppuccin (MIT, credited in THIRD_PARTY.md) with `@@HEX:role@@` placeholders, rendered per flavour with the nekoshell header |
| `gh` | `gh` | nothing; the user's `~/.config/gh/config.yml` is untouched | completions from `gh completion -s zsh` cached under `~/.cache/nekoshell/`; `GH_PAGER=delta` when delta is present | none (gh has no theme) |
| `mise` | `mise` | `~/.config/mise/config.toml` copied once, `copy_guard`, a commented empty template | `eval "$(mise activate zsh)"` in `plugin.zsh`; completions | none |
| `pure` | `pure` | `~/.config/nekoshell/pure-colors.zsh` rendered | `plugin.zsh` sets `NEKOSHELL_PROMPT=pure`, adds the formula's `site-functions` to `fpath`, `promptinit; prompt pure` | zstyles `:prompt:pure:*` colours from the flavour; `conflicts = ["p10k"]` and p10k gains `conflicts = ["pure"]` |

Doctor rows: yazi binary and rendered theme flavour; gh binary and
`gh auth status` (warn when logged out); mise binary and `mise doctor`
exit status; pure prompt function present and colours rendered.

## 3. AI tool plugins

Only tools that can be verified end to end on this Mac and that have
something to theme. Claude Code is installed here; OpenCode installs from
Homebrew and has full custom themes. Left out: Codex (no theme key; it adopts
the terminal palette, which is already Catppuccin) and Aider (colours only
through environment variables, a python install, not verifiable here). Both
can follow the same shape later.

### `ai` (base)

- `bin/nekoshell-ai-welcome TOOL`: prints the banner. Default text:

  ```text
  Welcome to Claude Code. You are in nekoshell on main.
  Last commit 5832ced "Merge pull request #5" 2 hours ago.
  ```

  Outside a repository: `You are in ~/Downloads, not a git repository.`
  Colours from the flavour through the rendered `~/.config/nekoshell/ai/colors.zsh`.
- Template copied once to `~/.config/nekoshell/ai/welcome.txt` with
  `@@TOOL@@ @@PROJECT@@ @@BRANCH@@ @@COMMIT@@ @@SUBJECT@@ @@WHEN@@ @@DIR@@`;
  a `welcome.TOOL.txt` beside it wins for that tool.
- `NEKOSHELL_AI_WELCOME=0` silences it; it is silent when stdout is not a
  tty.
- `nekoshell ai welcome [TOOL]` previews, `nekoshell ai edit` opens the
  template, `nekoshell ai status` lists which tool plugins are enabled and
  what each has applied.

### `claude-code`

- `casks = []`, `requires = []`: Claude Code is usually installed by its own
  installer or npm; the install hook checks `command -v claude` and prints
  the Homebrew cask command when it is missing rather than installing a
  second copy.
- `plugin.zsh`: a `claude` function that prints the banner and then runs
  `command claude "$@"`, except with `-p`, `--print`, `-v`, `--version`,
  `-h`, `--help`, `mcp`, `config`, `plugin`, `update`, `doctor` or when not
  on a tty.
- Theme: `claude config set -g theme dark|light` (light for latte), through
  the CLI so `~/.claude.json` is never edited by hand.
- Status line: `~/.config/nekoshell/ai/claude-statusline.sh` rendered per
  flavour (model, project, branch, context percentage in Catppuccin
  colours); the `statusLine` key of `~/.claude/settings.json` is set with
  python3's json module, the previous value recorded in
  `~/.config/nekoshell/ai/claude-previous.json`; uninstall restores it.
- Doctor: binary, theme matches the flavour, status line points at our
  script.

### `opencode`

- `requires = ["opencode"]`.
- Theme: `~/.config/opencode/themes/nekoshell.json` rendered per flavour from
  `files/theme.json.tmpl` (defs are the palette roles); the `theme` key of
  `~/.config/opencode/tui.json` set to `nekoshell`, previous value recorded,
  restored on uninstall.
- `plugin.zsh`: an `opencode` function with the banner, skipped for `run`,
  `serve`, `auth`, `--version`, `--help`, or no tty.
- Doctor: binary, rendered theme flavour, `tui.json` names it.

## 4. Spotify search bar

`nekoshell spotify search [QUERY]` (alias `sps`), in `cmd/spotify.sh` with
`bin/nekoshell-spotify-search` doing the work:

- `spotify_player search QUERY` returns JSON; python3 flattens tracks,
  albums, artists and playlists into typed rows:
  `♪ Get Lucky · Daft Punk · Random Access Memories`, `▣ Discovery · Daft Punk`,
  `♩ Daft Punk`, `≡ This Is Daft Punk · Spotify`. Shows and episodes are not
  playable through the CLI and are left out.
- fzf with the prompt `Spotify ›`; with no query the list fills as you type
  (`--bind change:reload`, debounced); with a query it opens on those results.
  Without fzf, a numbered menu.
- Enter plays on the active device: `playback start track --id` or
  `playback start context --id ID playlist|album|artist`. No active device:
  `no Spotify device is active; start nekoshell music first`, status 1.
- spotify_player 0.25.1 fails to parse some responses (a null where it wants
  a boolean; `daft punk` triggers it, `hello` does not). The command reports
  the upstream error in one line and exits 1; it never hangs.
- Tests: the `spotify_player` fake answers `search` with canned JSON and
  records `playback` calls; an `fzf` fake prints the first line.

## Documentation

One page per new plugin under `docs/plugins/`, the table in
`docs/plugins/README.md`, the profiles table, greet's page rewritten around
providers, `plugins/greet/README.md` and the four provider READMEs, the
THIRD_PARTY.md credits (anime, minecraft, colorscripts, yazi flavours),
CHANGELOG 0.2.0.

## Order and verification

Four pull requests, each green on lint, test, install matrix and commits,
each applied on this Mac before merging: `pokemon` enabled and the greeting
measured in the five terminals; `anime` enabled once to see it draw; yazi,
gh, mise and pure added and the prompt seen in a real shell; `claude-code`
applied and a Claude Code session started from a real terminal; `opencode`
installed from Homebrew and started once; `nekoshell spotify search`
playing a track on the running player.
