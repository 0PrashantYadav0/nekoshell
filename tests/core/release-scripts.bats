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
