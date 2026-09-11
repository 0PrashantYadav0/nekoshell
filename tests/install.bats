#!/usr/bin/env bats
load helpers

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_SKIP_PREFLIGHT=1
  printf 'export EDITOR=vim\nalias gs="git status"\nexport ZSH="$HOME/.oh-my-zsh"\n' > "$HOME/.zshrc"
  echo 'old' > "$HOME/.config/starship.toml"
  mkdir -p "$HOME/.config/fastfetch"
  echo 'mine' > "$HOME/.config/fastfetch/mine.jsonc"
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
  [ -x "$HOME/.local/bin/pokemon-colorscripts" ]
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

@test "a second uninstall keeps the restored files" {
  "$REPO_ROOT/install.sh" --yes
  "$REPO_ROOT/uninstall.sh" --yes
  run "$REPO_ROOT/uninstall.sh" --yes
  [ "$status" -eq 0 ]
  grep -q 'EDITOR=vim' "$HOME/.zshrc"
  [ "$(cat "$HOME/.config/starship.toml")" = "old" ]
}

@test "files nekoshell does not own are left alone" {
  "$REPO_ROOT/install.sh" --yes
  [ "$(cat "$HOME/.config/fastfetch/mine.jsonc")" = "mine" ]
  "$REPO_ROOT/uninstall.sh" --yes
  [ "$(cat "$HOME/.config/fastfetch/mine.jsonc")" = "mine" ]
}

# The Brewfile must only name things `brew bundle` can still resolve on a
# current Homebrew. `homebrew/bundle` was deprecated and tapping it now fails
# the whole bundle; iTerm2 is a precondition installed outside Homebrew, so a
# cask for it collides with an existing /Applications/iTerm.app.
@test "Brewfile has no deprecated tap and does not install iTerm2" {
  run grep -c '^tap ' "$REPO_ROOT/Brewfile"
  [ "$output" = "0" ]
  run grep -c '^cask "iterm2"' "$REPO_ROOT/Brewfile"
  [ "$output" = "0" ]
  grep -q '^cask "font-jetbrains-mono-nerd-font"' "$REPO_ROOT/Brewfile"
  grep -q '^brew "spotify_player"' "$REPO_ROOT/Brewfile"
}

# Backups must never live inside the checkout: re-cloning or cleaning the repo
# would take the user's original files with it.
@test "backup_root_inside_checkout spots a nested backup root" {
  run bash -c "source '$REPO_ROOT/lib/log.sh'; source '$REPO_ROOT/lib/backup.sh'; NEKOSHELL_ROOT=/a/checkout NEKOSHELL_BACKUP_ROOT=/a/checkout/backup backup_root_inside_checkout"
  [ "$status" -eq 0 ]
  run bash -c "source '$REPO_ROOT/lib/log.sh'; source '$REPO_ROOT/lib/backup.sh'; NEKOSHELL_ROOT=/a/checkout NEKOSHELL_BACKUP_ROOT=$HOME/.local/share/nekoshell/backup backup_root_inside_checkout"
  [ "$status" -ne 0 ]
}

# iTerm2 rewrites its own plist when it quits, so prefs written while it runs
# are thrown away. Refusing beats writing a value that quietly disappears.
@test "--iterm-prefs refuses while iTerm2 is running" {
  FAKE_ITERM_RUNNING=1 run "$REPO_ROOT/install.sh" --iterm-prefs
  [ "$status" -ne 0 ]
  [[ "$output" != *"defaults write"* ]]
}

@test "--iterm-prefs writes the prefs when iTerm2 is not running" {
  run "$REPO_ROOT/install.sh" --iterm-prefs
  [ "$status" -eq 0 ]
  [[ "$output" == *"Default Bookmark Guid"* ]]
}

# greet.conf is the user's to edit, so the installer copies it once instead of
# stowing a symlink back into the checkout.
@test "greet.conf is copied, not linked, and never overwritten" {
  "$REPO_ROOT/install.sh" --yes >/dev/null
  [ -f "$HOME/.config/nekoshell/greet.conf" ]
  [ ! -L "$HOME/.config/nekoshell/greet.conf" ]
  echo 'POKEMON_SHARE=0' > "$HOME/.config/nekoshell/greet.conf"
  "$REPO_ROOT/install.sh" --yes >/dev/null
  [ "$(cat "$HOME/.config/nekoshell/greet.conf")" = "POKEMON_SHARE=0" ]
}

# A dotfiles user's ~/.zshrc is a symlink. The aliases are at the far end of it,
# and the link has to be resolved before the backup moves it out of the way.
@test "a symlinked .zshrc is migrated from its target" {
  mkdir -p "$HOME/dotfiles"
  printf 'alias dot="echo dotfiles"\n' > "$HOME/dotfiles/zshrc"
  rm -f "$HOME/.zshrc"
  ln -s "$HOME/dotfiles/zshrc" "$HOME/.zshrc"
  run "$REPO_ROOT/install.sh" --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"symlink to $HOME/dotfiles/zshrc"* ]]
  grep -q 'alias dot="echo dotfiles"' "$HOME/.config/nekoshell/zsh/local.zsh"
  backup="$(ls -d "$HOME"/.local/share/nekoshell/backup/*/ | head -1)"
  [ -L "$backup/.zshrc" ]
}
