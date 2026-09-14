#!/usr/bin/env bats
# scripts/check-commit-msg.sh is what the commit-msg hook and the CI commits
# job run, so its rules are tested here rather than by making bad commits.
load ../helpers
setup() {
  setup_tmp_home
  C="$REPO_ROOT/scripts/check-commit-msg.sh"
  MSG="$HOME/msg"
}
teardown() { teardown_tmp_home; }

check() { printf '%b' "$1" > "$MSG"; run "$C" "$MSG"; }

@test "a conventional subject with a signoff passes" {
  check 'feat(core): add a thing\n\nSigned-off-by: A Person <a@example.com>\n'
  [ "$status" -eq 0 ]
}
@test "an unknown type is refused" {
  check 'feature: add a thing\n\nSigned-off-by: A Person <a@example.com>\n'
  [ "$status" -eq 1 ]
  assert_contains "$output" "not a conventional commit"
}
@test "an upper-case description is refused" {
  check 'feat: Add a thing\n\nSigned-off-by: A Person <a@example.com>\n'
  [ "$status" -eq 1 ]
}
@test "a trailing full stop is refused" {
  check 'feat: add a thing.\n\nSigned-off-by: A Person <a@example.com>\n'
  [ "$status" -eq 1 ]
}
@test "a 73-character subject is refused" {
  local long; long="feat: $(printf 'x%.0s' $(seq 1 67))"
  check "$long\n\nSigned-off-by: A Person <a@example.com>\n"
  [ "$status" -eq 1 ]
  assert_contains "$output" "keep it to 72"
}
@test "a body without a blank second line is refused" {
  check 'feat: add a thing\nbody right away\n\nSigned-off-by: A Person <a@example.com>\n'
  [ "$status" -eq 1 ]
  assert_contains "$output" "second line must be blank"
}
@test "a malformed Co-Authored-By trailer is refused" {
  check 'feat: add a thing\n\nCo-Authored-By: nobody\nSigned-off-by: A Person <a@example.com>\n'
  [ "$status" -eq 1 ]
  assert_contains "$output" "Co-Authored-By: Name <email>"
}
@test "a well-formed Co-Authored-By trailer passes" {
  check 'feat: add a thing\n\nCo-Authored-By: Pair <pair@example.com>\nSigned-off-by: A Person <a@example.com>\n'
  [ "$status" -eq 0 ]
}
@test "merge, revert, fixup and squash messages are accepted as they are" {
  check 'Merge pull request #1 from x/y\n'; [ "$status" -eq 0 ]
  check 'Revert "feat: add a thing"\n\nThis reverts commit abc.\n'; [ "$status" -eq 0 ]
  check 'fixup! feat: add a thing\n'; [ "$status" -eq 0 ]
  check 'squash! feat: add a thing\n'; [ "$status" -eq 0 ]
}
@test "git's comment lines are ignored" {
  check 'feat: add a thing\n\nSigned-off-by: A Person <a@example.com>\n# Please enter the commit message\n# Changes to be committed:\n'
  [ "$status" -eq 0 ]
}
