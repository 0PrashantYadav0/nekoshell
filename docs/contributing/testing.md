# Testing

`bats -r tests` is the suite. It runs on a laptop and on macOS in CI, and it never touches your real home, never runs a real `brew` and never writes into the checkout.

Three directories under `tests/` hold everything the tests stand on: `helpers.bash`, `fakes/` and `fixtures/`.

## tests/helpers.bash

Every test file starts with `load ../helpers`, then calls `setup_tmp_home` in `setup` and `teardown_tmp_home` in `teardown`.

`setup_tmp_home` makes a throwaway `HOME` under `$TMPDIR`, outside the checkout:

> The throwaway HOME lives outside the checkout on purpose. Backups land under `$HOME`, and the installer refuses to write them inside the checkout, so a HOME under `tests/` would make every install test trip that guard. `pwd -P` because macOS temp dirs are reached through symlinks and the installer resolves paths.

It also creates `.config`, `.cache`, `.local/share` and `.local/bin`, sets `XDG_CONFIG_HOME`, and unsets `TERM_PROGRAM`, `KITTY_WINDOW_ID`, `GHOSTTY_RESOURCES_DIR`, `GHOSTTY_QUICK_TERMINAL` and `WEZTERM_EXECUTABLE`:

> The terminal bats happens to run in must not leak into the test: the running terminal wins `terminal_current`, so a suite run from kitty would otherwise see kitty where the toml says fake. Tests that want a terminal set these themselves.

`teardown_tmp_home` only removes a directory whose name matches `*/nekoshell-home.??????`, so a test that changed `HOME` cannot delete something else.

### The four assertions

`assert_contains`, `assert_not_contains`, `assert_matches` and `assert_not_matches`. Use them instead of `[[ ]]`, for the reason the file gives:

> bats 1.14: a failing `[[ ]]` that is not a test's last statement does not fail the test, because a compound command's status does not reach the ERR trap bats installs. `[ ]` and ordinary commands do. These are plain functions, so their non-zero return stops the test, and they print what they expected next to what they got instead of leaving a bare line number.

`assert_not_matches` exists because a negative assertion on log output wants a regex: the doctor pads its columns with a run of spaces whose width the caller cannot know, so a literal can never match and never fails.

## tests/fakes

A fake is a short executable that stands in for a tool. Put `tests/fakes` in front of `PATH` in `setup` and the code under test finds the fake instead of the real thing:

```bash
export PATH="$REPO_ROOT/tests/fakes:$PATH"
```

A fake varies its behaviour through `FAKE_*` environment variables the test sets. `tests/fakes/brew` is the convention in one header:

```bash
# Fake Homebrew. FAKE_BREW_INSTALLED / FAKE_BREW_CASKS / FAKE_BREW_TAPS list
# what is "installed". FAKE_BREW_FAIL=1 makes `brew install` (formula or
# --cask) fail, to exercise a plugin_add that has to handle a failed install.
```

The fakes that do more than echo their arguments:

| Fake | What it stands in for |
| --- | --- |
| `brew` | Homebrew. `FAKE_BREW_INSTALLED`, `FAKE_BREW_CASKS`, `FAKE_BREW_TAPS`, `FAKE_BREW_FAIL` |
| `git` | `clone` fabricates whichever checkout the destination names; `fetch`, `checkout` and `-C` are no-ops |
| `curl` | writes a stub wherever `-o` points instead of reaching the network; `FAKE_CURL_SOURCE` names a file to deliver |
| `defaults` | records the call and reports no stored value; `defaults read -g AppleInterfaceStyle` is special-cased |
| `fzf` | `--zsh` prints the bindings; `FAKE_FZF_PICK=N` picks the Nth line of stdin |
| `gh` | completions a zsh can source, a login state, a version; `FAKE_GH_LOGGED_OUT=1` |
| `kitten` | echoes the invocation; never opens a panel or talks to a kitty socket |
| `pgrep` | iTerm2 is running only when `FAKE_ITERM_RUNNING=1` |
| `sips` | writes a stub where `--out` points instead of converting an image |
| `spotify_player` | `search` answers with the fixture JSON, or `FAKE_SPOTIFY_SEARCH_JSON`; `FAKE_SPOTIFY_SEARCH_FAIL=1` |
| `sw_vers` | reports `FAKE_SW_VERS_PRODUCT_VERSION`, 26.0 when unset |
| `yazi` | records the directory it "quit in" where `--cwd-file` points; `FAKE_YAZI_CWD` |
| `atuin`, `mise`, `zoxide` | an `init`/`activate` output a zsh can eval with no side effects |
| `bat` | `--list-themes` answers once `bat cache --build` has run, which the doctor's bat theme row checks |
| `fastfetch`, `nvim`, `tmux`, `aerospace`, `pokemon-colorscripts` | enough for a doctor row and for `command -v` |
| `btop`, `delta`, `eza`, `fd`, `lazygit`, `open`, `rg`, `spotify`, `starship` | echo their arguments |

`tests/fakes-ai` and `tests/fakes-nofzf` are small PATH directories built from symlinks into `tests/fakes`, for tests that need one tool present or absent: the AI plugin tests use the first, the spotify search tests the second.

## tests/fixtures

Fixtures are sample plugins and adapters, pointed at with `NEKOSHELL_PLUGINS_DIR` and `NEKOSHELL_TERMINALS_DIR`, so the core tests exercise the machinery without depending on a real plugin:

```bash
export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
```

| Fixture plugin | What it is for |
| --- | --- |
| `demo` | one of everything: every hook, both file trees, `bin/`, `cmd/`, `antidote.txt`. Copy it to start a real plugin |
| `broken` | its install hook always fails, so a failed add can be tested |
| `clash` | `conflicts = ["demo"]` |
| `needs-demo` | `requires_plugins = ["demo"]` |
| `kitty-only` | `terminals = ["kitty"]`, for the terminal support refusal |
| `guarded` | a `copy_guard`, for the skipped copy |
| `flaky-doctor` | a doctor hook ending on a guarded, legitimately-false check |
| `fakeart`, `fakeart2` | art providers: a `greet-art` and `requires_plugins = ["greet"]` |
| `fakeplayer`, `otherplayer` | `tags = ["media"]` and a `bin/`, so the `auto` pick and the `music_player` setting can be told apart |

| Fixture terminal | What it is for |
| --- | --- |
| `bare` | a name and nothing else, so the contract's own defaults are what is tested |
| `fake` | detection through `FAKE_TERM`, an apply and a background that log, and a doctor row |

## Running them

```bash
bats -r tests                      # everything, as CI runs it
bats tests/core/cli.bats           # one file
bats tests/core/cli.bats -f "name" # the tests whose name matches
bats -r tests/plugins              # one directory
make test                          # bats -r tests
make check                         # scripts/lint.sh, then bats -r tests
```

`make hooks` puts the same checks in front of a commit: pre-commit lints the staged files, commit-msg checks the message, pre-push runs the suite.

## What CI runs

`.github/workflows/ci.yml` has four jobs, and branch protection on `main` requires all four:

| Job | Runner | What it does |
| --- | --- | --- |
| `lint` | ubuntu-latest | `NEKOSHELL_LINT_STRICT=1 scripts/lint.sh`, with the linter versions pinned to what `make tools` installs |
| `test` | macos-latest | `bats -r tests` |
| `install` | macos-latest | `nekoshell install --check --profile full --terminal <id>` against a throwaway `HOME`, once per terminal adapter |
| `commits` | ubuntu-latest | `scripts/check-commit-msg.sh --range` over every commit of the pull request |

`NEKOSHELL_LINT_STRICT=1` turns a missing linter into a failure. On a laptop it is a skip with a note, so a contributor without every tool still gets the checks they have.

## Writing a test for a bug

Write the failing test first and watch it fail, then fix the code.

1. Find the file the behaviour belongs in: `tests/core/<lib>.bats` for a library, `tests/plugins/<name>.bats` for a plugin, `tests/terminals/<id>.bats` for an adapter.
2. Add a `@test` that reproduces the bug, with the shortest setup that shows it.
3. `bats tests/core/plugin.bats -f "the name you gave it"`. It must fail, and the message must say what went wrong.
4. Fix the code. Run the one test, then `make check`.

A test that never failed proves nothing about the fix.
