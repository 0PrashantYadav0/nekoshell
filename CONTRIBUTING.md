# Contributing

## Setup

```bash
brew install bats-core shellcheck
```

## Before opening a pull request

Run the tests:

```bash
bats -r tests
```

Run the linter, the same line CI runs:

```bash
shellcheck -x install.sh uninstall.sh bin/* core/lib/*.sh core/cmd/*.sh \
  terminals/adapter.sh terminals/*/adapter.sh \
  plugins/*/*.sh plugins/*/bin/* plugins/*/cmd/*.sh \
  tests/helpers.bash tests/fakes/*
```

Both must pass. Tests never touch your real `$HOME`: `tests/helpers.bash` gives
every test a throwaway one, and `tests/fakes/` stands in for the tools an
install would otherwise run.

## Commit messages

Use [conventional commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, and so on.

## Code style

Keep every script bash 3.2 compatible. macOS ships bash 3.2 as `/bin/bash`, and
nekoshell must run there without requiring a newer bash from Homebrew. No
associative arrays, no `${var,,}`, no `mapfile`. Every executable starts with
`set -euo pipefail`.

## Images

Do not add copyrighted images to the art pack or anywhere else in the repo.
Only openly licensed sample images belong in `plugins/greet/art/`.

## Vendored files

If you add a file copied from another project, list it in [THIRD_PARTY.md](THIRD_PARTY.md) with its source and license.

Generated files (`core/theme/palettes.json`, `plugins/greet/data/pokemon.tsv`)
are committed, with the generator beside them pinning the upstream commit it
downloaded from. Re-run the generator and commit its output rather than editing
the data by hand.

## Colours

Every colour in the rig comes from `core/theme/palettes.json`. If you add
something that carries colour, render it from a template through
`core/lib/theme.sh` rather than writing a hex value into a config, or
`nekoshell theme` will leave it behind on the old flavour.

## Adding a plugin

[docs/WRITING-A-PLUGIN.md](docs/WRITING-A-PLUGIN.md) is the full guide. The
short version:

1. Copy `tests/fixtures/plugins/demo` to `plugins/<name>/` — it is a working
   plugin with one of everything.
2. Fill in `plugin.toml`'s nine keys: `name`, `summary`, `requires`, `casks`,
   `taps`, `requires_plugins`, `terminals`, `conflicts`, `tags`.
3. Write `README.md` with its five sections: `## What it does`, `## Installs`,
   `## Files`, `## After install`, `## Remove`.
4. Add `tests/plugins/<name>.bats`.

`tests/core/repo.bats` checks the first three for every plugin, so a missing
key or section fails the build.
