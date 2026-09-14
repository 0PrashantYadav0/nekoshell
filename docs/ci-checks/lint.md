# lint

The static checks. One job on Linux, because none of them needs macOS.

## What it runs

```bash
NEKOSHELL_LINT_STRICT=1 scripts/lint.sh
```

`scripts/lint.sh` is the only linter definition in the repository. It runs six
checks, in this order, and reports all of them before exiting:

1. `shellcheck -x` over every shell file git tracks (by extension, or by a
   `sh`/`bash` shebang; `.bats` files are excluded because shellcheck cannot
   parse `@test` blocks).
2. `shfmt -l -i 2 -ci -bn` over the same files: two-space indent, case arms
   indented, binary operators may start a line.
3. The repository shape rules: every file under `bin/`, `plugins/*/bin/`,
   `tests/fakes/` and `scripts/`, plus `install.sh` and `uninstall.sh`, is
   executable; no shell file has CRLF line endings; every `plugin.toml` has the
   nine keys `name`, `summary`, `requires`, `casks`, `taps`, `requires_plugins`,
   `terminals`, `conflicts`, `tags`; every `terminals/*/adapter.sh` defines the
   ten `terminal_*` functions.
4. `actionlint` over `.github/workflows/`.
5. `yamllint -c .yamllint.yaml` over every tracked `.yml` and `.yaml`.
6. `markdownlint-cli2` over every tracked `.md`.

`NEKOSHELL_LINT_STRICT=1` turns "this linter is not installed" from a yellow
skip into a failure, so CI can never pass because a tool was missing.

## When it runs

Every push to `main` and every pull request. Will be required by the branch
ruleset on `main`.

## Run it locally

```bash
make tools          # brew install the six linters, once
make lint           # the whole tree
scripts/lint.sh FILE...   # only these files, what the pre-commit hook does
scripts/lint.sh --fix     # rewrite the shell files with shfmt instead of reporting
```

The linters are pinned in `ci.yml` to the versions `make tools` installs on a
Mac today: shellcheck 0.11.0, shfmt 3.14.1, actionlint 1.7.7 and
markdownlint-cli2 0.17.2, with yamllint from apt. The reason is reproducibility:
Ubuntu's shellcheck is two years behind, and shfmt changes its formatting
between minor versions, so an unpinned job would report findings a contributor
cannot see.

## Reading a failure

The job log has one line per check: `ok` for a pass, `skip` for a missing tool
(never on CI), `fail` for a failure, with the tool's own output above the `fail`
line. `scripts/lint.sh` runs all six even after one fails, so the log shows
everything wrong at once rather than the first thing.

## Common fixes

- `shfmt: the files above need formatting`: run `scripts/lint.sh --fix` (or
  `make fmt`) and commit the result.
- `not executable`: `chmod +x` the file and `git update-index --chmod=+x FILE`
  if git still records mode 644.
- `missing key 'tags'`: add the key to the plugin's `plugin.toml`, empty if it
  has no value; all nine keys have to be present.
- `missing terminal_panel()`: a new adapter has to define all ten functions,
  even the ones that only log "not supported".
- markdownlint `MD032`/`MD031`: put a blank line around lists and fenced code
  blocks. Line length is off, so long paragraphs are fine on one line.
