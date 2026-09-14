# release

The five jobs a `v*` tag starts, in `.github/workflows/release.yml`.

## What it runs

`verify` -> `check` -> `package` -> `release` -> `tap`, chained with `needs` so
nothing is published before the checks pass.

```yaml
verify:   needs: []                # ubuntu: the tag matches VERSION and the CHANGELOG
check:    needs: [verify]          # macos:  NEKOSHELL_LINT_STRICT=1 scripts/lint.sh, bats -r tests
package:  needs: [verify, check]   # ubuntu: scripts/package.sh --ref "$GITHUB_REF_NAME" --out dist
release:  needs: [verify, package] # ubuntu: gh release create
tap:      needs: [verify, release] # ubuntu: scripts/render-formula.sh into the tap
```

- `verify` strips the leading `v` from the tag, fails unless it equals `VERSION`
  exactly, fails unless `CHANGELOG.md` has a dated `## X.Y.Z - YYYY-MM-DD`
  heading, runs `scripts/changelog-section.sh X.Y.Z` to prove the section has a
  body, and exports `version` as a job output the other four read.
- `check` installs `bats-core shellcheck shfmt actionlint yamllint
  markdownlint-cli2` with Homebrew on `macos-latest` and runs the full lint and
  the full suite. It is the same pair of commands `make check` runs.
- `package` runs `scripts/package.sh`, which is `git archive` of the tag with
  the prefix `nekoshell-X.Y.Z/`, honouring the `export-ignore` entries in
  `.gitattributes`, plus `shasum -a 256` into `SHA256SUMS`. Both files go up as
  the `dist` artifact with `if-no-files-found: error`.
- `release` downloads `dist`, writes the CHANGELOG section to `notes.md` and
  runs `gh release create "v$VERSION" --title "nekoshell $VERSION" --notes-file
  notes.md` with the tarball and `SHA256SUMS` attached. It uses
  `GH_TOKEN: ${{ github.token }}`, which the workflow's `permissions:
  contents: write` covers.
- `tap` downloads `dist`, checks out `0PrashantYadav0/homebrew-nekoshell` into
  `tap/` with the `HOMEBREW_TAP_TOKEN` secret, renders
  `packaging/homebrew/nekoshell.rb.tmpl` with the version and the sha from
  `SHA256SUMS` into `tap/Formula/nekoshell.rb`, and pushes one commit
  `nekoshell X.Y.Z` as `github-actions[bot]` to the tap's `main`. The whole file
  is rendered rather than two lines patched, so the template in this repository
  is the only source of truth. If the rendered file is identical to what the tap
  already has, the job prints `formula already at X.Y.Z` and exits 0.

The secret: `HOMEBREW_TAP_TOKEN`, a fine-grained personal access token with
contents write on `0PrashantYadav0/homebrew-nekoshell` and nothing else. It is
the only secret any workflow uses.

## When it runs

On a push of a tag matching `v*`, which is what `scripts/release.sh` creates and
`git push origin main --follow-tags` sends. Never on a pull request, so none of
these five is a required check.

## Run it locally

Everything except the two publishing steps:

```bash
scripts/changelog-section.sh 0.2.0          # what verify checks and release uses as notes
make check                                  # what check runs
make package                                # dist/nekoshell-0.2.0.tar.gz and dist/SHA256SUMS
scripts/render-formula.sh --version 0.2.0 \
  --sha256 "$(awk '{print $1}' dist/SHA256SUMS)"
```

`scripts/release.sh 0.2.0 --dry-run` prints what the tagging half would do
without touching anything.

## Reading a failure

Which job failed tells you where you are:

- `verify` failed: nothing was published. The tag and `VERSION` disagree, or the
  CHANGELOG heading is still `(unreleased)`. The message names which.
- `check` failed: nothing was published. A lint finding or a test failure that
  should have been caught before the tag; read it as
  [lint.md](lint.md) or [test.md](test.md).
- `package` failed: nothing was published. Usually `no such ref`, which means
  the tag was deleted while the run was in flight.
- `release` failed: still nothing published, unless it failed part way through
  `gh release create`, in which case a Release exists with some assets missing.
- `tap` failed: the GitHub Release exists and is correct, only the formula is
  stale. This is the half-failed case worth knowing: the token expired, or the
  tap repository does not exist yet.

## Common fixes

- Tag and `VERSION` disagree: delete the tag locally and remotely
  (`git tag -d v0.2.0 && git push origin :refs/tags/v0.2.0`), fix, and run
  `scripts/release.sh` again. Never move a tag that a Release already points at.
- A half-published Release: delete the Release and the tag
  (`gh release delete v0.2.0 --yes --cleanup-tag`), fix, tag again.
- `tap` failed alone: do not redo the release. Re-run that one job from the
  Actions page once the token is fixed, or render the formula locally and
  commit it to the tap by hand.
- `HOMEBREW_TAP_TOKEN` missing or expired: `tap`'s checkout fails with a 404 on
  a repository that does exist, because a token without access cannot tell the
  difference. Reissue the token and set it again under the repository's secrets.

The owner's walk-through of a release, start to finish, is
[release-process.md](release-process.md).
