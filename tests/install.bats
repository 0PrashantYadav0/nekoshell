#!/usr/bin/env bats
load helpers

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_SKIP_PREFLIGHT=1
  printf 'export EDITOR=vim\nalias gs="git status"\nexport ZSH="$HOME/.oh-my-zsh"\n' > "$HOME/.zshrc"
  echo 'old' > "$HOME/.config/starship.toml"
}
teardown() { teardown_tmp_home; }

@test "--dry-run runs nothing and prints the plan" {
  run "$REPO_ROOT/install.sh" --dry-run --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"brew bundle"* ]]
  [[ "$output" == *"stow"* ]]
  [ ! -L "$HOME/.zshrc" ]
  [ "$(cat "$HOME/.config/starship.toml")" = "old" ]
  [ ! -d "$HOME/.local/share/nekoshell/backup" ]
  [ ! -f "$HOME/.config/nekoshell/root" ]
  [ ! -f "$HOME/.gitconfig" ]
}

@test "install backs up, migrates aliases, stows, records root, writes the profile" {
  run "$REPO_ROOT/install.sh" --yes
  [ "$status" -eq 0 ]
  [ -L "$HOME/.zshrc" ]
  [ "$HOME/.zshrc" -ef "$REPO_ROOT/stow/zsh/.zshrc" ]
  [ "$(cat "$HOME/.config/nekoshell/root")" = "$REPO_ROOT" ]
  backup="$(ls -d "$HOME"/.local/share/nekoshell/backup/*/ | head -1)"
  [ -f "$backup/.zshrc" ]
  [ "$(cat "$backup/.config/starship.toml")" = "old" ]
  grep -q '^\.zshrc$' "$backup/manifest.txt"
  grep -q 'alias gs="git status"' "$HOME/.config/nekoshell/zsh/local.zsh"
  ! grep -q 'oh-my-zsh' "$HOME/.config/nekoshell/zsh/local.zsh"
  [ -f "$HOME/Library/Application Support/iTerm2/DynamicProfiles/nekoshell.json" ]
  [ -L "$HOME/.local/bin/pokemon-colorscripts" ]
  grep -q 'nekoshell' "$HOME/.gitconfig"
  [[ "$output" == *"Default Bookmark Guid"* ]]
}

@test "install is idempotent" {
  "$REPO_ROOT/install.sh" --yes
  run "$REPO_ROOT/install.sh" --yes
  [ "$status" -eq 0 ]
  [ "$(ls -d "$HOME"/.local/share/nekoshell/backup/*/ | wc -l | tr -d ' ')" = "1" ]
  [ "$(grep -c 'nekoshell' "$HOME/.gitconfig")" = "1" ]
  [ "$HOME/.zshrc" -ef "$REPO_ROOT/stow/zsh/.zshrc" ]
}

@test "--check after install reports nothing to do" {
  "$REPO_ROOT/install.sh" --yes
  run "$REPO_ROOT/install.sh" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to do"* ]]
}

@test "prefs are deferred while iTerm2 is running" {
  FAKE_ITERM_RUNNING=1 run "$REPO_ROOT/install.sh" --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"pending"* ]]
  [[ "$output" == *"install.sh --iterm-prefs"* ]]
}

@test "uninstall restores the backup" {
  "$REPO_ROOT/install.sh" --yes
  run "$REPO_ROOT/uninstall.sh" --yes
  [ "$status" -eq 0 ]
  [ ! -L "$HOME/.zshrc" ]
  grep -q 'EDITOR=vim' "$HOME/.zshrc"
  [ "$(cat "$HOME/.config/starship.toml")" = "old" ]
  [ ! -f "$HOME/Library/Application Support/iTerm2/DynamicProfiles/nekoshell.json" ]
}
