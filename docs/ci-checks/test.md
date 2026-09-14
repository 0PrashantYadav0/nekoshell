# test

The bats suite.

## What it runs

```bash
bats -r tests
```

On `macos-latest`, after `brew install bats-core`. `-r` walks the whole
directory, so `tests/core`, `tests/terminals` and `tests/plugins` all run in one
job.

## When it runs

Every push to `main` and every pull request. Required by the branch ruleset on
`main`.

The runner is macOS because the code is: the adapters call `defaults`, `open`
and `sips`, the installer refuses anything but Darwin, and a Linux runner would
prove nothing about either.

## Run it locally

```bash
brew install bats-core
make test                          # everything
bats tests/core/install.bats       # one file
bats -f "theme" -r tests           # tests whose name matches
bats --count -r tests              # parse every file and count the tests
```

Three things shape every test. `tests/helpers.bash` gives each test a throwaway
`HOME` under `$TMPDIR` (`setup_tmp_home` / `teardown_tmp_home`) and the
`assert_contains`, `assert_not_contains`, `assert_matches` and
`assert_not_matches` functions, which are plain functions rather than `[[ ]]`
because a failing `[[ ]]` in the middle of a bats test does not fail it.
`tests/fakes/` holds stand-in executables (`brew`, `git`, `starship`, `open`,
`defaults` and the rest) that a test puts on `PATH` so nothing real is installed
or launched; `tests/fakes-ai/` and `tests/fakes-nofzf/` are variants of that
directory for the AI plugin tests and for proving the no-fzf fallbacks.
`tests/fixtures/` holds sample plugins and terminal adapters (`demo`, `broken`,
`clash`, `fake`, `bare` and more) so the plugin and terminal code can be tested
against contracts that never change under it.

## Reading a failure

bats prints `not ok N <name>` with the file and line of the statement that
failed, then every line the test wrote to stdout and stderr prefixed with `#`.
The assertion helpers print what they expected next to what they got, so a
failing `assert_contains` shows both strings rather than a bare line number.

## Common fixes

- A test passes alone and fails in the suite: something leaked through the
  environment. Check that the test calls `setup_tmp_home` and that it unsets the
  terminal variables it cares about; `setup_tmp_home` already clears
  `TERM_PROGRAM`, `KITTY_WINDOW_ID` and the Ghostty and WezTerm ones.
- A test touches the real machine: put `tests/fakes` first on `PATH` instead of
  calling the real tool. The release script tests are the exception, they use
  the real `git` against a throwaway repository under the throwaway `HOME`.
- `bats: command not found` on a laptop: `brew install bats-core`.
- A new test file that does not run: it has to end in `.bats` and live under
  `tests/`, and `bats --count FILE` has to parse it.
