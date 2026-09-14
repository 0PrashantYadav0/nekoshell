# CI checks

Every automated check nekoshell runs, where it is defined, and the command that
reproduces it on a laptop. Three workflows hold them: `.github/workflows/ci.yml`
on every push to `main` and every pull request, `.github/workflows/release.yml`
on a `v*` tag, and `.github/workflows/real-install.yml` on a schedule.

| Job | Workflow | Runner | When | Required on PRs | Locally |
| --- | --- | --- | --- | --- | --- |
| [lint](lint.md) | `ci.yml` | ubuntu-latest | push to `main`, pull request | yes | `make lint` |
| [test](test.md) | `ci.yml` | macos-latest | push to `main`, pull request | yes | `make test` |
| [install (iterm2, kitty, ghostty, warp, terminal-app)](install.md) | `ci.yml` | macos-latest | push to `main`, pull request | yes | see [install.md](install.md) |
| [commits](commits.md) | `ci.yml` | ubuntu-latest | pull request only | yes | `scripts/check-commit-msg.sh --range main..HEAD` |
| [secrets](secrets.md) | `ci.yml` | ubuntu-latest | push to `main`, pull request | yes | `make secrets` |
| [verify](release.md) | `release.yml` | ubuntu-latest | push of a `v*` tag | no | `scripts/changelog-section.sh X.Y.Z` |
| [check](release.md) | `release.yml` | macos-latest | push of a `v*` tag | no | `make check` |
| [package](release.md) | `release.yml` | ubuntu-latest | push of a `v*` tag | no | `make package` |
| [release](release.md) | `release.yml` | ubuntu-latest | push of a `v*` tag | no | not reproducible, it publishes |
| [tap](release.md) | `release.yml` | ubuntu-latest | push of a `v*` tag | no | `scripts/render-formula.sh --version X.Y.Z --sha256 HEX` |
| [install (minimal, terminal-app)](real-install.md) | `real-install.yml` | macos-latest | Mondays 06:00 UTC, manual dispatch | no | `./install.sh --yes --profile minimal --terminal terminal-app` |

## The required checks and the branch ruleset

The branch ruleset does not exist yet. It is created on `main` once these check
names are final, in the audit that precedes the first release, and it will
require the nine names `ci.yml` produces: `lint`, `test`, `install (iterm2)`,
`install (kitty)`, `install (ghostty)`, `install (warp)`,
`install (terminal-app)`, `commits` and `secrets`. The five `install` names come
from the matrix, so a new terminal adapter adds a name that will have to be
added to the ruleset too. `commits` only runs on a pull request, which is why it
is safe to require it: a push straight to `main` never waits for a job that does
not start. Nothing in `release.yml` or `real-install.yml` will be required,
because neither runs on a pull request at all.

## The same checks, earlier

`make hooks` points `core.hooksPath` at `.githooks`, and the three hooks run
subsets of the same scripts before anything leaves the machine: `pre-commit`
runs `scripts/lint.sh` over the staged files (from the index, not the working
tree) and `bats --count` over staged test files, `commit-msg` runs
`scripts/check-commit-msg.sh` on the message you just wrote, and `pre-push` runs
`bats -r tests`. They call the same scripts CI calls, so a hook that passes and
a job that fails means the tool versions differ, not the rules.

## The pages

- [lint.md](lint.md), [test.md](test.md), [install.md](install.md),
  [commits.md](commits.md), [secrets.md](secrets.md): the five pull request checks.
- [release.md](release.md): the five jobs a tag starts.
- [real-install.md](real-install.md): the weekly Homebrew install.
- [release-process.md](release-process.md): the owner's steps for cutting a release.
