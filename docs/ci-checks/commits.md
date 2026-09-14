# commits

Every commit message of a pull request is a conventional commit with a sign-off.

## What it runs

```bash
scripts/check-commit-msg.sh --range "$BASE_SHA..$HEAD_SHA"
```

with `$BASE_SHA` and `$HEAD_SHA` from the pull request event, after a checkout
with `fetch-depth: 0` so the whole range exists on the runner. The script walks
`git rev-list --no-merges` over the range and checks every message against four
rules:

1. The subject is a conventional commit: `type(scope)?!?: description`, with the
   type one of `feat fix docs style refactor perf test build ci chore revert`, a
   description that does not start with a capital and does not end in a full
   stop, and at most 72 characters. Failing it prints
   `subject is not a conventional commit: '<subject>'` followed by
   `expected: type(scope): lower-case description   (types: feat fix docs ...)`,
   or `subject is N characters; keep it to 72`.
2. A body, when there is one, is separated from the subject by a blank line:
   `the second line must be blank (subject, blank line, body)`.
3. A `Co-Authored-By` trailer, if the message has one at all, is well formed:
   `the Co-Authored-By trailer must read: Co-Authored-By: Name <email>`.
4. The message carries a `Signed-off-by` trailer, the Developer Certificate of
   Origin: `missing Signed-off-by trailer; commit with: git commit -s`.

Messages git writes itself are accepted as they are: `Merge ...`,
`Revert "..."`, `fixup! ...` and `squash! ...`.

## When it runs

On pull requests only (`if: github.event_name == 'pull_request'`); there is no
range to check on a direct push. Will be required by the branch ruleset on
`main`, which is safe precisely because every change to `main` arrives through a
pull request.

## Run it locally

```bash
make hooks                                         # commit-msg runs it on every commit
scripts/check-commit-msg.sh --range main..HEAD     # the whole branch, what CI does
scripts/check-commit-msg.sh .git/COMMIT_EDITMSG    # one message in a file
git commit -s -m "fix(plugin): stop the doctor lying about fzf"
```

`git commit -s` is the part people forget. `git config format.signOff true` does
not apply to `git commit`, so there is no way to make it automatic other than
the flag.

## Reading a failure

Each bad commit prints its rule failures, then a line
reading `in commit <short sha> <subject>`, indented by two spaces. The job checks every commit before exiting,
so one run lists all of them.

## Common fixes

- The last commit only: `git commit --amend -s -m "fix(core): the new subject"`,
  then `git push --force-with-lease`.
- A range missing sign-offs: `git rebase --signoff main` adds the trailer to
  every commit on the branch, then `git push --force-with-lease`. It rewrites
  the commits, so tell anyone else on the branch first.
- A range with bad subjects: `git rebase -i` is not available to an agent
  running without a terminal. Either amend the commits one at a time while
  walking the branch, or squash the branch into one good commit:
  `git reset --soft main && git commit -s -m "feat(scope): one subject"`.
- A merge commit flagged: it should not be, `--no-merges` skips them. If one is
  flagged it is not a real merge commit, it is a normal commit whose subject
  starts with something else.
