# Contributing

## Setup

```bash
brew install bats-core shellcheck
```

## Before opening a pull request

Run the tests:

```bash
bats tests
```

Run the linter:

```bash
shellcheck -x install.sh uninstall.sh lib/*.sh bin/*
```

Both must pass.

## Commit messages

Use [conventional commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, and so on.

## Code style

Keep every script bash 3.2 compatible. macOS ships bash 3.2 as `/bin/bash`, and nekoshell must run there without requiring a newer bash from Homebrew.

## Images

Do not add copyrighted images to the art pack or anywhere else in the repo. Only openly licensed sample images belong in `art/`.

## Vendored files

If you add a file copied from another project, list it in [THIRD_PARTY.md](THIRD_PARTY.md) with its source and license.
