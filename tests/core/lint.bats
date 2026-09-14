#!/usr/bin/env bats
# The repository shape rules in scripts/lint.sh are the first line CI holds:
# a plugin.toml missing a key or a bin file that is not executable is refused
# before the suite runs. They are tested here against a throwaway repository
# that breaks each rule on purpose. The external linters (shellcheck, shfmt,
# actionlint, yamllint, markdownlint) are kept off PATH so only the shape
# rules speak.
load ../helpers
setup() {
  setup_tmp_home
  R="$HOME/repo"
  mkdir -p "$R/scripts" "$R/bin" "$R/plugins/p" "$R/terminals/t"
  cd "$R"
  git init -q -b main . 2>/dev/null || {
    git init -q .
    git checkout -q -b main
  }
  git config user.name a
  git config user.email a@example.com
  cp "$REPO_ROOT/scripts/lint.sh" scripts/lint.sh
  chmod +x scripts/lint.sh
  printf '#!/usr/bin/env bash\necho hi\n' >bin/nekoshell
  chmod +x bin/nekoshell
  cp "$REPO_ROOT/plugins/fzf/plugin.toml" plugins/p/plugin.toml
  cp "$REPO_ROOT/tests/fixtures/terminals/fake/adapter.sh" terminals/t/adapter.sh
  # The fixture adapter leaves some functions at the default; give it all ten.
  for fn in terminal_font_name terminal_remove; do grep -q "^$fn()" terminals/t/adapter.sh || printf '%s() { :; }\n' "$fn" >>terminals/t/adapter.sh; done
  git add -A
  git commit -q -m "seed"
  # No linters on this PATH: the shape rules alone decide.
  LINT_PATH="/usr/bin:/bin"
}
teardown() { teardown_tmp_home; }

lint() { PATH="$LINT_PATH" run scripts/lint.sh; }

@test "a clean tree passes the shape rules" {
  lint
  [ "$status" -eq 0 ]
  assert_contains "$output" "ok   repository shape"
}
@test "a plugin.toml missing a key is refused by name" {
  grep -v '^tags' plugins/p/plugin.toml >t && mv t plugins/p/plugin.toml
  git commit -q -am "break"
  lint
  [ "$status" -eq 1 ]
  assert_contains "$output" "plugins/p/plugin.toml: missing key 'tags'"
}
@test "an adapter missing a function is refused by name" {
  grep -v '^terminal_doctor' terminals/t/adapter.sh >t && mv t terminals/t/adapter.sh
  git commit -q -am "break"
  lint
  [ "$status" -eq 1 ]
  assert_contains "$output" "terminals/t/adapter.sh: missing terminal_doctor()"
}
@test "a bin file that is not executable is refused" {
  chmod -x bin/nekoshell
  git add bin/nekoshell
  git commit -q -m "break"
  lint
  [ "$status" -eq 1 ]
  assert_contains "$output" "bin/nekoshell: not executable"
}
@test "a shell file with CRLF is refused" {
  printf '#!/usr/bin/env bash\r\necho hi\r\n' >bin/nekoshell
  git commit -q -am "break"
  lint
  [ "$status" -eq 1 ]
  assert_contains "$output" "bin/nekoshell: CRLF line endings"
}
