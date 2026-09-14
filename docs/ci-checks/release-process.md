# Cutting a release

The owner's page. A release is one tag: everything after the push is
`.github/workflows/release.yml`, described job by job in [release.md](release.md).

## Before you start

- `main` is clean and up to date, and its CI is green.
- `CHANGELOG.md` has a `## X.Y.Z (unreleased)` heading with the notes under it.
  That section becomes the GitHub Release notes verbatim, so write it for
  readers, not for yourself.
- The repository has the `HOMEBREW_TAP_TOKEN` secret, a fine-grained personal
  access token with contents write on `0PrashantYadav0/homebrew-nekoshell`.
- The tap repository exists with a `Formula/` directory. Without it the first
  four jobs still succeed and only `tap` fails.
- Last Monday's [real-install](real-install.md) run passed. It is the only check
  that runs a real `brew`, and a formula renamed upstream is better found now.

## The two commands

```bash
scripts/release.sh 0.2.0            # or: make release VERSION=0.2.0
git push origin main --follow-tags
```

`scripts/release.sh` refuses a version that is not `X.Y.Z`, a branch other than
`main`, a dirty tree, a tag that already exists, and a CHANGELOG without the
`## X.Y.Z (unreleased)` heading. It then writes `VERSION`, dates the heading to
today in UTC, commits `chore(release): X.Y.Z` signed off, and tags `vX.Y.Z`
annotated with `nekoshell X.Y.Z`. It pushes nothing; the second command does
that. `scripts/release.sh 0.2.0 --dry-run` prints what it would do and changes
nothing.

The branch ruleset on `main` requires pull requests, and this pushes a release
commit straight to `main`; the repository admin has a bypass on that ruleset, so
the push works for the owner and for nobody else.

## Watch it

```bash
gh run watch
gh run view --log-failed        # when something goes red
```

Five jobs in order: `verify`, `check`, `package`, `release`, `tap`. `check` is
the slow one, a full lint and the whole bats suite on a macOS runner.

## Verify what was published

```bash
gh release view v0.2.0
gh release download v0.2.0 --dir /tmp/rel
cd /tmp/rel && shasum -a 256 -c SHA256SUMS
tar -tzf nekoshell-0.2.0.tar.gz | head
```

`shasum -c` has to print `nekoshell-0.2.0.tar.gz: OK`. The listing has to show
`nekoshell-0.2.0/bin/nekoshell` and no `.github`, `.githooks` or `.planning`:
those are `export-ignore` in `.gitattributes`, and `tests/` is deliberately kept.

Then the tap:

```bash
gh repo view 0PrashantYadav0/homebrew-nekoshell
gh api repos/0PrashantYadav0/homebrew-nekoshell/commits/main --jq '.commit.message'
```

The newest commit should read `nekoshell 0.2.0` and its `Formula/nekoshell.rb`
should carry the new `url` and `sha256`. If the tap runs its own CI, wait for it.

Last, the user's path:

```bash
brew update
brew upgrade nekoshell          # or, the first time: brew tap 0PrashantYadav0/nekoshell && brew install nekoshell
nekoshell version
```

## When it fails half way

- `verify`, `check` or `package` failed. Nothing was published. Delete the tag
  in both places, fix the problem on `main`, and start again:

  ```bash
  git tag -d v0.2.0
  git push origin :refs/tags/v0.2.0
  ```

  The `chore(release): 0.2.0` commit is already on `main`. Either revert it, or
  amend it as part of the fix and force-push, which the admin bypass allows.

- `release` failed part way. A Release may exist with assets missing. Delete it
  and the tag together, then start again:

  ```bash
  gh release delete v0.2.0 --yes --cleanup-tag
  ```

- `tap` failed and everything before it passed. This is the common one, and it
  does not need a new release. The GitHub Release is correct; only the formula
  is stale. Fix the token, then re-run the `tap` job from the Actions page. If
  that is not possible, render and commit the formula by hand:

  ```bash
  gh release download v0.2.0 --dir /tmp/rel --pattern SHA256SUMS
  scripts/render-formula.sh --version 0.2.0 \
    --sha256 "$(awk '{print $1}' /tmp/rel/SHA256SUMS)" >Formula/nekoshell.rb
  ```

- Everything passed but the release is wrong. Never move a tag a Release points
  at; people and Homebrew have already fetched it. Cut `0.2.1` instead.
