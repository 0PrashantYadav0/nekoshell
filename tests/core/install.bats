#!/usr/bin/env bats
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export NEKOSHELL_PROFILES_DIR="$HOME/profiles"; mkdir -p "$NEKOSHELL_PROFILES_DIR"
  echo demo > "$NEKOSHELL_PROFILES_DIR/minimal.txt"; printf 'demo\nneeds-demo\n' > "$NEKOSHELL_PROFILES_DIR/full.txt"
  export NEKOSHELL_SKIP_PREFLIGHT=1 FAKE_TERM=1
  NK="$REPO_ROOT/bin/nekoshell"
}
teardown() { teardown_tmp_home; }

@test "install --yes --profile minimal links the zshrc, writes the toml, applies terminal, enables plugins" {
  run "$NK" install --yes --profile minimal
  [ "$status" -eq 0 ]
  [ -L "$HOME/.zshrc" ]; [ "$(readlink "$HOME/.zshrc")" = "$REPO_ROOT/core/zsh/.zshrc" ]
  [ "$(cat "$HOME/.config/nekoshell/root" 2>/dev/null)" = "" ]
  grep -q "^root = \"$REPO_ROOT\"" "$HOME/.config/nekoshell/nekoshell.toml"
  grep -q '^terminal = "fake"' "$HOME/.config/nekoshell/nekoshell.toml"
  grep -q '^plugins = \["demo"\]' "$HOME/.config/nekoshell/nekoshell.toml"
  grep -q '^profile = "minimal"' "$HOME/.config/nekoshell/nekoshell.toml"
  grep -q 'fake apply mocha' "$HOME/.cache/nekoshell/hooks.log"
  [ -f "$HOME/.config/starship.toml" ]
  assert_contains "$output" "ok   demo"
}
@test "install backs up an existing zshrc and migrates its aliases" {
  printf 'alias k=kubectl\nexport FOO=bar\n' > "$HOME/.zshrc"
  "$NK" install --yes --profile minimal >/dev/null
  grep -q 'alias k=kubectl' "$HOME/.config/nekoshell/zsh/local.zsh"
  [ "$(find "$HOME/.local/share/nekoshell/backup" -name .zshrc | wc -l | tr -d ' ')" -eq 1 ]
}
@test "install --with and --without adjust the profile" {
  run "$NK" install --yes --profile full --without needs-demo
  grep -q '^plugins = \["demo"\]' "$HOME/.config/nekoshell/nekoshell.toml"
  run "$NK" install --yes --profile minimal --with needs-demo
  grep -q '^plugins = \["demo", "needs-demo"\]' "$HOME/.config/nekoshell/nekoshell.toml"
}
@test "install --check changes nothing and exits 0" {
  run "$NK" install --check --profile minimal
  [ "$status" -eq 0 ]; [ ! -e "$HOME/.zshrc" ]; [ ! -e "$HOME/.config/nekoshell/nekoshell.toml" ]
  assert_contains "$output" "would"
}
@test "install without a tty and without --profile picks minimal and says so" {
  run "$NK" install --yes </dev/null
  assert_contains "$output" "no --profile given and no terminal to ask on: using minimal"
}
@test "install is idempotent" {
  "$NK" install --yes --profile minimal >/dev/null
  run "$NK" install --yes --profile minimal; [ "$status" -eq 0 ]
  [ "$(find "$HOME/.local/share/nekoshell/backup" -type f | wc -l | tr -d ' ')" -eq 0 ]
}
@test "install migrates a v0.1 machine" {
  mkdir -p "$HOME/.config/nekoshell"; echo latte > "$HOME/.config/nekoshell/theme"; echo "$REPO_ROOT" > "$HOME/.config/nekoshell/root"
  ln -s "$REPO_ROOT/stow/zsh/.zshrc" "$HOME/.zshrc"
  run "$NK" install --yes --profile minimal
  [ "$status" -eq 0 ]
  grep -q '^theme = "latte"' "$HOME/.config/nekoshell/nekoshell.toml"
  [ ! -e "$HOME/.config/nekoshell/theme" ]; [ ! -e "$HOME/.config/nekoshell/root" ]
  [ "$(readlink "$HOME/.zshrc")" = "$REPO_ROOT/core/zsh/.zshrc" ]
}
@test "uninstall restores the backup and removes links, keeps local.zsh" {
  printf 'alias k=kubectl\n' > "$HOME/.zshrc"
  "$NK" install --yes --profile minimal >/dev/null
  run "$NK" uninstall --yes
  [ "$status" -eq 0 ]
  [ ! -L "$HOME/.zshrc" ]; grep -q 'alias k=kubectl' "$HOME/.zshrc"
  [ -f "$HOME/.config/nekoshell/zsh/local.zsh" ]
  [ ! -e "$HOME/.config/demo/conf" ]
}
