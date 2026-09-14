#!/usr/bin/env bats
# Homebrew installs the tree at PREFIX/Cellar/nekoshell/VERSION/libexec and
# links PREFIX/bin/nekoshell into it. brew upgrade deletes that Cellar
# directory, so a root recorded or linked by version breaks on the first
# upgrade. The dispatcher has to prefer PREFIX/opt/nekoshell/libexec, the link
# Homebrew keeps pointing at the current version.
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export NEKOSHELL_PROFILES_DIR="$HOME/profiles"
  mkdir -p "$NEKOSHELL_PROFILES_DIR"
  echo demo >"$NEKOSHELL_PROFILES_DIR/minimal.txt"
  export NEKOSHELL_SKIP_PREFLIGHT=1 FAKE_TERM=1
  # A fake Homebrew prefix outside HOME, shaped the way the formula lays it out.
  PREFIX="$(cd "$(mktemp -d "${NEKOSHELL_TEST_TMP_PREFIX%/}/nekoshell-prefix.XXXXXX")" && pwd -P)"
  CELLAR="$PREFIX/Cellar/nekoshell/0.2.0"
  mkdir -p "$CELLAR/libexec" "$PREFIX/opt" "$PREFIX/bin"
  local d
  for d in bin core plugins terminals profiles data VERSION; do
    ln -s "$REPO_ROOT/$d" "$CELLAR/libexec/$d"
  done
  ln -s "../Cellar/nekoshell/0.2.0" "$PREFIX/opt/nekoshell"
  ln -s "../Cellar/nekoshell/0.2.0/libexec/bin/nekoshell" "$PREFIX/bin/nekoshell"
}
teardown() {
  teardown_tmp_home
  case "${PREFIX:-}" in */nekoshell-prefix.??????) rm -rf "$PREFIX" ;; esac
}

@test "a Cellar install records and links the opt path, not the versioned one" {
  run "$PREFIX/bin/nekoshell" install --yes --profile minimal
  [ "$status" -eq 0 ]
  grep -q "^root = \"$PREFIX/opt/nekoshell/libexec\"" "$HOME/.config/nekoshell/nekoshell.toml"
  [ "$(readlink "$HOME/.zshrc")" = "$PREFIX/opt/nekoshell/libexec/core/zsh/.zshrc" ]
  # NEKOSHELL_PLUGINS_DIR is set above to the fixtures path directly (as every
  # plugin test does, since "demo" is a fixture, not a real plugin), so this
  # link resolves through that fixed path, not through the swapped root; the
  # first two assertions are what actually exercise the opt-path swap.
  [ "$(readlink "$HOME/.config/demo/conf")" = "$REPO_ROOT/tests/fixtures/plugins/demo/files/link/.config/demo/conf" ]
}

@test "a Cellar install without an opt link keeps the Cellar path" {
  rm "$PREFIX/opt/nekoshell"
  run "$PREFIX/bin/nekoshell" install --yes --profile minimal
  [ "$status" -eq 0 ]
  grep -q "^root = \"$CELLAR/libexec\"" "$HOME/.config/nekoshell/nekoshell.toml"
}

@test "a git checkout keeps its own path" {
  run "$REPO_ROOT/bin/nekoshell" install --yes --profile minimal
  [ "$status" -eq 0 ]
  grep -q "^root = \"$REPO_ROOT\"" "$HOME/.config/nekoshell/nekoshell.toml"
}
