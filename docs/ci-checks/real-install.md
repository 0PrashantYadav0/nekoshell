# real-install

The only check that runs Homebrew for real.

## What it runs

One job on `macos-latest`, two steps, each with its own throwaway `HOME`
(steps do not share shell state, so `HOME` has to be set again in the second):

```bash
export HOME
HOME="$(mktemp -d)"
export PATH="$HOME/.local/bin:$PATH"
./install.sh --yes --profile minimal --terminal terminal-app
```

```bash
export HOME
HOME="$(mktemp -d)"
export PATH="$HOME/.local/bin:$PATH"
./install.sh --yes --profile minimal --terminal terminal-app >/dev/null
./bin/nekoshell doctor
./bin/nekoshell plugin add fzf
./bin/nekoshell doctor --plugin fzf
```

This is a real install: `brew install` really runs, the formulas and casks the
`minimal` profile names are really fetched, and the files really land, in the
throwaway `HOME` rather than the runner's own. Preflight is left on, because a
macOS runner has all four things it wants: Darwin, Homebrew, zsh and git.
Terminal.app ships with macOS, so `--terminal terminal-app` names an adapter
whose application really exists. The second install is idempotent and fast,
because Homebrew already has everything from the first. Each step also puts
`~/.local/bin` on `PATH` the way the zshrc does for a real shell, so the
doctor sees the tools plugins link there.

## When it runs

`cron: '0 6 * * 1'`, Mondays at 06:00 UTC, and `workflow_dispatch` on demand.
Not on pull requests, and not a required check: a Homebrew outage or a formula
renamed upstream would otherwise block every unrelated pull request, and the
job takes minutes rather than seconds.

## Run it locally

```bash
gh workflow run real-install.yml     # start it now, on the default branch
gh run watch                         # follow it
```

On a Mac, the same thing by hand, remembering that it installs real software:

```bash
HOME="$(mktemp -d)" ./install.sh --yes --profile minimal --terminal terminal-app
```

## Reading a failure

The installer's own numbered steps are in the log. A failure in step 3 (the
plugins) with a `brew` error underneath it is the thing this job exists to
catch: a formula that was renamed, a cask that moved to another tap, or a tap
that disappeared. A failure in `nekoshell doctor` after a clean install means a
plugin installed something but the doctor looks for it somewhere else.

`ci.yml`'s `install` job cannot see any of this. It runs `--check` against
fakes, so it proves the plugin graph and the adapters are consistent and nothing
about the outside world.

## Common fixes

- `Error: No available formula with the name "x"`: the formula was renamed.
  Update the `requires` line in that plugin's `plugin.toml` and add a note to
  the CHANGELOG, because existing users hit the same error on their next
  `nekoshell plugin add`.
- A cask that now needs a tap: add the tap to the plugin's `taps` key.
- The job failed once and passes on a re-run: usually a Homebrew or a GitHub
  download timeout. Re-run it from the Actions page before changing anything.
- Nobody noticed a failure for weeks: the run is on a schedule, so it fails
  silently unless someone looks. Check it before cutting a release.
