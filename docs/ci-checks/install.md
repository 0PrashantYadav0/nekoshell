# install

The installer against a throwaway `HOME`, once per terminal adapter.

## What it runs

Five jobs from one matrix (`iterm2`, `kitty`, `ghostty`, `warp`,
`terminal-app`), each two steps:

```bash
HOME="$(mktemp -d)" NEKOSHELL_SKIP_PREFLIGHT=1 \
  ./bin/nekoshell install --check --profile full --terminal "$TERMINAL"
```

```bash
HOME="$(mktemp -d)" ./bin/nekoshell version
HOME="$(mktemp -d)" ./bin/nekoshell help
HOME="$(mktemp -d)" ./bin/nekoshell terminal list
```

`--check` resolves everything and writes nothing: the profile's plugin list, the
dependency and conflict graph, the terminal adapter and the files it would link
or copy. `NEKOSHELL_SKIP_PREFLIGHT=1` drops the Darwin, Homebrew, zsh and git
probes. A macOS runner passes all four, which is why
[real-install.md](real-install.md) leaves preflight on; here it is belt and
braces, because `--check` mutates nothing and has no business asking whether
Homebrew is installed before it resolves a plugin list. The `HOME` in front of
each command is a fresh empty directory, so nothing the job does can reach the
runner's own dotfiles.

## When it runs

Every push to `main` and every pull request, on `macos-latest`. All five names
(`install (iterm2)` through `install (terminal-app)`) will be required by the
branch ruleset on `main`.

## Run it locally

```bash
HOME="$(mktemp -d)" NEKOSHELL_SKIP_PREFLIGHT=1 \
  ./bin/nekoshell install --check --profile full --terminal kitty
```

Swap `kitty` for any id `./bin/nekoshell terminal list` prints. The `full`
profile is the widest one, so it is the one that catches a profile naming a
plugin that no longer exists.

## Reading a failure

The installer prints a numbered step per phase and one line per decision.
A failure names the thing it could not resolve: `no terminal matched
--terminal X`, an unknown plugin in a profile, an unmet `requires_plugins`, or
two enabled plugins that declare each other in `conflicts`.

What this job proves: every profile names plugins that exist, every plugin's
dependency and conflict declarations agree, every adapter loads and answers the
ten functions, and the CLI runs with no config at all. What it cannot prove:
nothing here runs a real `brew`, so a formula renamed upstream or a cask that
moved is invisible to it. That is what
[real-install.md](real-install.md) is for.

## Common fixes

- `no terminal matched --terminal X`: the matrix id has to be a directory under
  `terminals/`. A renamed adapter needs the matrix in `ci.yml` and the branch
  ruleset's required check names updated together.
- An unknown plugin: a profile under `profiles/` names a plugin directory that
  was renamed or removed.
- A failure only in the second step: the CLI read something from `HOME` that is
  not there on a clean machine. Every command has to work with no config.
