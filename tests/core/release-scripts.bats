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

@test "package.sh writes the tarball and its checksum for a ref" {
  make_repo
  mkdir -p bin .github; printf '#!/usr/bin/env bash\necho hi\n' > bin/nekoshell; chmod +x bin/nekoshell
  echo x > .github/thing
  printf '.github export-ignore\n' > .gitattributes
  git add -A; git commit -q -s -m "chore: files"
  git tag v0.2.0
  run scripts/package.sh --out "$HOME/dist"
  [ "$status" -eq 0 ]
  [ -f "$HOME/dist/nekoshell-0.2.0.tar.gz" ]
  run tar -tzf "$HOME/dist/nekoshell-0.2.0.tar.gz"
  assert_contains "$output" "nekoshell-0.2.0/bin/nekoshell"
  assert_contains "$output" "nekoshell-0.2.0/VERSION"
  assert_not_contains "$output" ".github"
  sum="$(shasum -a 256 "$HOME/dist/nekoshell-0.2.0.tar.gz" | awk '{print $1}')"
  [ "$(cat "$HOME/dist/SHA256SUMS")" = "$sum  nekoshell-0.2.0.tar.gz" ]
}
@test "package.sh --ref HEAD works before a tag exists and refuses a missing ref" {
  make_repo
  run scripts/package.sh --ref HEAD --out "$HOME/dist"
  [ "$status" -eq 0 ]
  [ -f "$HOME/dist/nekoshell-0.2.0.tar.gz" ]
  run scripts/package.sh --ref v9.9.9 --out "$HOME/dist"
  [ "$status" -eq 1 ]
  assert_contains "$output" "no such ref"
}

@test "render-formula.sh fills url and sha256 and leaves no placeholder" {
  local sha; sha="$(printf 'a%.0s' $(seq 1 64))"
  run "$S/render-formula.sh" --version 0.2.0 --sha256 "$sha"
  [ "$status" -eq 0 ]
  assert_contains "$output" 'class Nekoshell < Formula'
  assert_contains "$output" 'url "https://github.com/0PrashantYadav0/nekoshell/releases/download/v0.2.0/nekoshell-0.2.0.tar.gz"'
  assert_contains "$output" "sha256 \"$sha\""
  assert_contains "$output" 'head "https://github.com/0PrashantYadav0/nekoshell.git", branch: "main"'
  assert_not_contains "$output" "@VERSION@"
  assert_not_contains "$output" "@URL@"
  assert_not_contains "$output" "@SHA256@"
}
@test "render-formula.sh refuses a sha that is not 64 hex characters" {
  run "$S/render-formula.sh" --version 0.2.0 --sha256 abc
  [ "$status" -eq 2 ]
}
@test "the rendered formula is valid ruby" {
  command -v ruby >/dev/null || skip "no ruby"
  local sha; sha="$(printf 'a%.0s' $(seq 1 64))"
  "$S/render-formula.sh" --version 0.2.0 --sha256 "$sha" > "$HOME/nekoshell.rb"
  run ruby -c "$HOME/nekoshell.rb"
  [ "$status" -eq 0 ]
}
