# secrets

gitleaks over the whole history, so a token in a fixture or a doc never lands.

## What it runs

```bash
gitleaks git --no-banner --redact .
```

after a checkout with `fetch-depth: 0`, because `gitleaks git` scans commits,
not the working tree: a secret that was committed and then removed is still in
the history and still has to be rotated.

gitleaks is pinned to 8.30.1 and downloaded from its release page rather than
taken from an action, so the version that runs is the version written in
`ci.yml`:

```bash
curl -sSfL "https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz" | tar -xz gitleaks
sudo mv gitleaks /usr/local/bin/gitleaks
```

`--redact` keeps the secret itself out of the public job log; the finding names
the file, the line and the rule, not the value.

There is no `.gitleaks.toml` in the repository, so gitleaks runs with its own
default rule set. If a rule ever produces a finding that is genuinely not a
secret, add `.gitleaks.toml` with an `[allowlist]` naming that path or that
regex, and say in a comment why the match is safe.

## When it runs

Every push to `main` and every pull request. Will be required by the branch
ruleset on `main`.

## Run it locally

```bash
brew install gitleaks
make secrets
```

Same command, same history. It takes a few seconds on this repository.

## Reading a failure

Each finding is a block: the rule id, the file and line, the commit and author,
and the redacted match. Read the rule id first. `generic-api-key` on a line of
example configuration is usually a false positive; a named rule
(`github-pat`, `slack-access-token`, `aws-access-token`) almost never is.

## Common fixes

- A real secret: rotate it first. Revoke the token or key at its provider before
  anything else, because the repository is public and the value is already out.
  Only then decide about history. Rewriting history with `git filter-repo` is
  optional once the secret is dead, and it breaks every existing clone and fork,
  so it is usually not worth it.
- A fixture that looks like a key: change the fixture. A test does not need a
  string shaped like a real token; `ghp_EXAMPLE` or `xxx` works as well and the
  finding goes away for good.
- A documented example: same answer, make the example obviously fake. Failing
  that, add the `.gitleaks.toml` allowlist entry described above.
