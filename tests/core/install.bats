#!/usr/bin/env bats
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export NEKOSHELL_PROFILES_DIR="$HOME/profiles"; mkdir -p "$NEKOSHELL_PROFILES_DIR"
  echo demo > "$NEKOSHELL_PROFILES_DIR/minimal.txt"; printf 'demo\nneeds-demo\n' > "$NEKOSHELL_PROFILES_DIR/full.txt"
  : > "$NEKOSHELL_PROFILES_DIR/empty.txt"
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
@test "install --terminal all configures every adapter and keeps the running one primary" {
  run "$NK" install --yes --profile minimal --terminal all
  [ "$status" -eq 0 ]
  grep -q '^terminals = \["bare", "fake"\]' "$HOME/.config/nekoshell/nekoshell.toml"
  grep -q '^terminal = "bare"' "$HOME/.config/nekoshell/nekoshell.toml"
  grep -q 'fake apply mocha' "$HOME/.cache/nekoshell/hooks.log"
  assert_contains "$output" "terminal: bare fake"
  run "$NK" install --yes --profile minimal --terminal fake,nope
  [ "$status" -eq 1 ]
  assert_contains "$output" "no terminal adapter named nope"
}
# Plugins bring their own formulas; starship, antidote and the font are
# core's, and only what is missing is asked of Homebrew.
@test "install puts starship, antidote and the Nerd Font in through Homebrew, only when missing" {
  run "$NK" install --yes --profile empty
  [ "$status" -eq 0 ]
  assert_contains "$output" "\$ brew install starship antidote"
  assert_contains "$output" "\$ brew install --cask font-jetbrains-mono-nerd-font"
  FAKE_BREW_INSTALLED="starship antidote" FAKE_BREW_CASKS="font-jetbrains-mono-nerd-font" run "$NK" install --yes --profile empty
  [ "$status" -eq 0 ]
  # The doctor's font row still names the cask; what must be gone is the call.
  assert_not_contains "$output" "\$ brew install"
}
@test "install backs up an existing zshrc and migrates its aliases" {
  printf 'alias k=kubectl\nexport FOO=bar\n' > "$HOME/.zshrc"
  "$NK" install --yes --profile minimal >/dev/null
  grep -q 'alias k=kubectl' "$HOME/.config/nekoshell/zsh/local.zsh"
  [ "$(find "$HOME/.local/share/nekoshell/backup" -name .zshrc | wc -l | tr -d ' ')" -eq 1 ]
}
@test "install --with and --without adjust the profile" {
  run "$NK" install --yes --profile full --without needs-demo
  [ "$status" -eq 0 ]
  grep -q '^plugins = \["demo"\]' "$HOME/.config/nekoshell/nekoshell.toml"
  run "$NK" install --yes --profile minimal --with needs-demo
  [ "$status" -eq 0 ]
  grep -q '^plugins = \["demo", "needs-demo"\]' "$HOME/.config/nekoshell/nekoshell.toml"
}
@test "install with an empty profile succeeds and records plugins = []" {
  run "$NK" install --yes --profile empty
  [ "$status" -eq 0 ]
  grep -q '^plugins = \[\]' "$HOME/.config/nekoshell/nekoshell.toml"
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
  [ -f "$HOME/.config/demo/mine.conf" ]
}
@test "install migrates and backs up a foreign zshrc symlink; uninstall restores it" {
  mkdir -p "$HOME/dotfiles"
  printf 'alias k=kubectl\n' > "$HOME/dotfiles/zshrc"
  ln -s "$HOME/dotfiles/zshrc" "$HOME/.zshrc"
  run "$NK" install --yes --profile minimal
  [ "$status" -eq 0 ]
  [ -L "$HOME/.zshrc" ]; [ "$(readlink "$HOME/.zshrc")" = "$REPO_ROOT/core/zsh/.zshrc" ]
  grep -q 'alias k=kubectl' "$HOME/.config/nekoshell/zsh/local.zsh"
  local backup_dir
  backup_dir="$(find "$HOME/.local/share/nekoshell/backup" -mindepth 1 -maxdepth 1 -type d | head -1)"
  [ -n "$backup_dir" ]
  [ -L "$backup_dir/.zshrc" ]
  [ "$(readlink "$backup_dir/.zshrc")" = "$HOME/dotfiles/zshrc" ]
  run "$NK" uninstall --yes
  [ "$status" -eq 0 ]
  [ -L "$HOME/.zshrc" ]
  [ "$(readlink "$HOME/.zshrc")" = "$HOME/dotfiles/zshrc" ]
}

# Critical: the renders write straight over whatever is at these paths, so a
# config of the user's own has to be in the backup set before step 5 runs.
@test "install backs up the configs it renders over; uninstall brings them back" {
  mkdir -p "$HOME/.config/fastfetch"
  printf '# my own starship\n' > "$HOME/.config/starship.toml"
  printf '{ "mine": true }\n' > "$HOME/.config/fastfetch/config.jsonc"
  "$NK" install --yes --profile minimal >/dev/null
  local dir
  dir="$(find "$HOME/.local/share/nekoshell/backup" -mindepth 1 -maxdepth 1 -type d | head -1)"
  [ -n "$dir" ]
  grep -q 'my own starship' "$dir/.config/starship.toml"
  grep -q 'mine' "$dir/.config/fastfetch/config.jsonc"
  grep -q 'nekoshell Starship config' "$HOME/.config/starship.toml"
  run "$NK" uninstall --yes
  [ "$status" -eq 0 ]
  grep -q 'my own starship' "$HOME/.config/starship.toml"
  grep -q 'mine' "$HOME/.config/fastfetch/config.jsonc"
}
@test "a second install does not back up the starship.toml it rendered itself" {
  "$NK" install --yes --profile minimal >/dev/null
  "$NK" install --yes --profile minimal >/dev/null
  [ "$(find "$HOME/.local/share/nekoshell/backup" -name starship.toml | wc -l | tr -d ' ')" -eq 0 ]
}
# Critical: every `plugin add` begins a backup set of its own, so by uninstall
# there is more than one and only the oldest holds the original ~/.zshrc.
@test "uninstall restores every backup set, not only the newest" {
  printf 'alias k=kubectl\n' > "$HOME/.zshrc"
  mkdir -p "$HOME/.config/demo"; printf 'my own demo conf\n' > "$HOME/.config/demo/conf"
  "$NK" install --yes --profile empty >/dev/null
  # Backup dirs are named to the second; without this both sets would be one.
  sleep 1
  "$NK" plugin add demo >/dev/null
  [ "$(find "$HOME/.local/share/nekoshell/backup" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" -eq 2 ]
  run "$NK" uninstall --yes
  [ "$status" -eq 0 ]
  [ ! -L "$HOME/.zshrc" ]
  grep -q 'alias k=kubectl' "$HOME/.zshrc"
  grep -q 'my own demo conf' "$HOME/.config/demo/conf"
}

# A v0.1 machine has every plugin's config already in place; a narrower profile
# would leave those files with nothing using them.
@test "a v0.1 install with no --profile uses the full profile and says so" {
  mkdir -p "$HOME/.config/nekoshell"; echo latte > "$HOME/.config/nekoshell/theme"
  run "$NK" install --yes </dev/null
  [ "$status" -eq 0 ]
  assert_contains "$output" "v0.1 install detected: using the full profile (pass --profile to choose)"
  grep -q '^profile = "full"' "$HOME/.config/nekoshell/nekoshell.toml"
  grep -q '^plugins = \["demo", "needs-demo"\]' "$HOME/.config/nekoshell/nekoshell.toml"
}
@test "install sweeps the v0.1 links the profile does not re-link, and keeps the user's own" {
  mkdir -p "$HOME/.config/atuin" "$HOME/.config/bat/themes" "$HOME/.config/lazygit"
  # Broken: v0.2 deleted the tree these pointed into.
  ln -s "$REPO_ROOT/stow/atuin/.config/atuin/config.toml" "$HOME/.config/atuin/config.toml"
  ln -s "$REPO_ROOT/stow/bat/.config/bat/themes/Catppuccin.tmTheme" "$HOME/.config/bat/themes/Catppuccin.tmTheme"
  # A link of the user's own, to a file that is really there: never touched.
  printf 'mine\n' > "$HOME/real-lazygit.yml"
  ln -s "$HOME/real-lazygit.yml" "$HOME/.config/lazygit/config.yml"
  run "$NK" install --yes --profile minimal
  [ "$status" -eq 0 ]
  assert_contains "$output" "v0.1 leftover: removing ~/.config/atuin/config.toml"
  [ ! -L "$HOME/.config/atuin/config.toml" ]
  [ ! -L "$HOME/.config/bat/themes/Catppuccin.tmTheme" ]
  [ -L "$HOME/.config/lazygit/config.yml" ]
  [ "$(readlink "$HOME/.config/lazygit/config.yml")" = "$HOME/real-lazygit.yml" ]
}
@test "install replaces a relative, dangling v0.1 link at ~/.zshrc without backing it up" {
  local rel
  rel="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$REPO_ROOT/stow/zsh/.zshrc" "$HOME")"
  ln -s "$rel" "$HOME/.zshrc"
  [ -L "$HOME/.zshrc" ]; [ ! -e "$HOME/.zshrc" ]
  run "$NK" install --yes --profile minimal
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.zshrc")" = "$REPO_ROOT/core/zsh/.zshrc" ]
  # v0.1's own link, not the user's: dropped rather than saved.
  [ "$(find "$HOME/.local/share/nekoshell/backup" -name .zshrc | wc -l | tr -d ' ')" -eq 0 ]
}
