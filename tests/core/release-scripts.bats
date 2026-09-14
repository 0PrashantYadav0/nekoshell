#!/usr/bin/env bats
# The release scripts. Each one runs against a copy of the repository in a
# throwaway git repo, so nothing here can tag or commit the real checkout.
load ../helpers
setup() {
  setup_tmp_home
  S="$REPO_ROOT/scripts"
  CL="$HOME/CHANGELOG.md"
  cat > "$CL" <<'EOF'
# Changelog

## 0.3.0 (unreleased)

- next thing

## 0.2.0 - 2026-09-20

### Plugins

- a plugin

### Fixes

- a fix

## 0.1.0

- first
EOF
}
teardown() { teardown_tmp_home; }

@test "changelog-section prints one version's body without surrounding blank lines" {
  run "$S/changelog-section.sh" 0.2.0 "$CL"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "### Plugins" ]
  [ "${lines[${#lines[@]}-1]}" = "- a fix" ]
  assert_not_contains "$output" "next thing"
  assert_not_contains "$output" "first"
}
@test "changelog-section finds an unreleased heading too" {
  run "$S/changelog-section.sh" 0.3.0 "$CL"
  [ "$status" -eq 0 ]
  [ "$output" = "- next thing" ]
}
@test "changelog-section fails for a version that has no section" {
  run "$S/changelog-section.sh" 9.9.9 "$CL"
  [ "$status" -eq 1 ]
  assert_contains "$output" "no section for 9.9.9"
}

# A throwaway repo with the real scripts and a CHANGELOG at 0.2.0 unreleased.
make_repo() {
  R="$HOME/repo"; mkdir -p "$R"; cd "$R"
  git init -q -b main . 2>/dev/null || { git init -q .; git checkout -q -b main; }
  git config user.name "A Person"; git config user.email "a@example.com"
  cp -R "$REPO_ROOT/scripts" "$R/scripts"
  printf '0.2.0\n' > VERSION
  printf '# Changelog\n\n## 0.2.0 (unreleased)\n\n- a thing\n\n## 0.1.0\n\n- first\n' > CHANGELOG.md
  git add -A; git commit -q -s -m "chore: seed"
}

@test "release.sh dates the changelog, writes VERSION, commits and tags" {
  make_repo
  run scripts/release.sh 0.2.0
  [ "$status" -eq 0 ]
  [ "$(cat VERSION)" = "0.2.0" ]
  grep -qE '^## 0.2.0 - [0-9]{4}-[0-9]{2}-[0-9]{2}$' CHANGELOG.md
  [ "$(git log -1 --format=%s)" = "chore(release): 0.2.0" ]
  git log -1 --format=%B | grep -q '^Signed-off-by: A Person <a@example.com>$'
  [ "$(git tag -l v0.2.0)" = "v0.2.0" ]
  [ "$(git cat-file -t v0.2.0)" = "tag" ]
  assert_contains "$output" "git push origin main --follow-tags"
}
@test "release.sh bumps VERSION to the version given" {
  make_repo
  printf '0.1.9\n' > VERSION; git commit -q -s -am "chore: older version"
  run scripts/release.sh 0.2.0
  [ "$status" -eq 0 ]
  [ "$(cat VERSION)" = "0.2.0" ]
}
@test "release.sh --dry-run changes nothing" {
  make_repo
  run scripts/release.sh 0.2.0 --dry-run
  [ "$status" -eq 0 ]
  assert_contains "$output" "would"
  grep -q '^## 0.2.0 (unreleased)$' CHANGELOG.md
  [ -z "$(git tag -l)" ]
}
@test "release.sh refuses a dirty tree, a wrong branch, an existing tag and a missing section" {
  make_repo
  echo x > dirty
  run scripts/release.sh 0.2.0; [ "$status" -eq 1 ]; assert_contains "$output" "not clean"
  rm dirty
  git checkout -q -b topic
  run scripts/release.sh 0.2.0; [ "$status" -eq 1 ]; assert_contains "$output" "release from main"
  git checkout -q main
  git tag v0.2.0
  run scripts/release.sh 0.2.0; [ "$status" -eq 1 ]; assert_contains "$output" "already exists"
  git tag -d v0.2.0 >/dev/null
  run scripts/release.sh 0.4.0; [ "$status" -eq 1 ]; assert_contains "$output" "no '## 0.4.0 (unreleased)' section"
  run scripts/release.sh 1.2; [ "$status" -eq 2 ]
}
