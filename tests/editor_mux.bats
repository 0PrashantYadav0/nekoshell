#!/usr/bin/env bats
load helpers

# Neovim and tmux. Both configs are the user's own files: copied once, never
# stowed and never overwritten, the same deal greet.conf gets. The flavour is
# the one thing nekoshell keeps hold of, and it reaches tmux through a separate
# one-line file the user's tmux.conf sources.

setup() {
  setup_tmp_home
  # Keep the machine's own PATH around. The fakes go in front of it for the
  # installer, but the parse checks need the real nvim and tmux when they exist,
  # and a fake would answer for them otherwise.
  NEKO_REAL_PATH="$PATH"
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_SKIP_PREFLIGHT=1
  export HOMEBREW_PREFIX=/nonexistent
}
teardown() { teardown_tmp_home; }

marker() { printf '%s\n' "$output" | sed -n "s/^$1=//p"; }

# have_real TOOL: true when TOOL is really installed on this machine, rather
# than being one of the fakes in tests/fakes.
have_real() {
  PATH="$NEKO_REAL_PATH" command -v "$1" >/dev/null 2>&1
}

stow_it() {
  mkdir -p "$HOME/.config/nekoshell/zsh"
  stow --no-folding -d "$REPO_ROOT/stow" -t "$HOME" zsh config
}

NVIM_FILES="init.lua lua/nekoshell/options.lua lua/nekoshell/keymaps.lua lua/nekoshell/plugins.lua"

@test "the Brewfile installs neovim and tmux" {
  grep -q '^brew "neovim"$' "$REPO_ROOT/Brewfile"
  grep -q '^brew "tmux"$' "$REPO_ROOT/Brewfile"
}

# Both are configs a user edits, so the installer copies them once. A symlink
# into the checkout would make every edit a change to the repo.
@test "the nvim and tmux configs are copied, not linked" {
  "$REPO_ROOT/install.sh" --yes >/dev/null
  for rel in $NVIM_FILES; do
    [ -f "$HOME/.config/nvim/$rel" ]
    [ ! -L "$HOME/.config/nvim/$rel" ]
  done
  [ -f "$HOME/.config/tmux/tmux.conf" ]
  [ ! -L "$HOME/.config/tmux/tmux.conf" ]
  grep -q 'nekoshell.options' "$HOME/.config/nvim/init.lua"
  grep -q 'catppuccin' "$HOME/.config/nvim/lua/nekoshell/plugins.lua"
}

@test "a re-install keeps your edits to both configs" {
  "$REPO_ROOT/install.sh" --yes >/dev/null
  echo '-- mine' >> "$HOME/.config/nvim/init.lua"
  echo '-- also mine' >> "$HOME/.config/nvim/lua/nekoshell/keymaps.lua"
  echo '# mine' >> "$HOME/.config/tmux/tmux.conf"
  "$REPO_ROOT/install.sh" --yes >/dev/null
  grep -q -- '-- mine' "$HOME/.config/nvim/init.lua"
  grep -q -- '-- also mine' "$HOME/.config/nvim/lua/nekoshell/keymaps.lua"
  grep -q '# mine' "$HOME/.config/tmux/tmux.conf"
}

# The first install is the one that replaces what was there. Anything it
# replaces has to be in the backup, or an existing setup is simply gone.
@test "an nvim or tmux config already in place is backed up first" {
  mkdir -p "$HOME/.config/nvim/lua/nekoshell" "$HOME/.config/tmux"
  echo 'old init' > "$HOME/.config/nvim/init.lua"
  echo 'old options' > "$HOME/.config/nvim/lua/nekoshell/options.lua"
  echo 'old tmux' > "$HOME/.config/tmux/tmux.conf"
  "$REPO_ROOT/install.sh" --yes >/dev/null
  backup="$(ls -d "$HOME"/.local/share/nekoshell/backup/*/ | head -1)"
  [ "$(cat "$backup/.config/nvim/init.lua")" = "old init" ]
  [ "$(cat "$backup/.config/nvim/lua/nekoshell/options.lua")" = "old options" ]
  [ "$(cat "$backup/.config/tmux/tmux.conf")" = "old tmux" ]
  grep -q '^\.config/nvim/init\.lua$' "$backup/manifest.txt"
  grep -q '^\.config/tmux/tmux\.conf$' "$backup/manifest.txt"
  # And the rig's own files took their place.
  grep -q 'nekoshell' "$HOME/.config/nvim/init.lua"
  grep -q 'nekoshell' "$HOME/.config/tmux/tmux.conf"
}

@test "the tmux plugin manager is cloned at the pinned commit" {
  grep -q '^tpm=[0-9a-f]\{40\}$' "$REPO_ROOT/deps.lock"
  run "$REPO_ROOT/install.sh" --yes
  [ "$status" -eq 0 ]
  [ -d "$HOME/.tmux/plugins/tpm" ]
  assert_contains "$output" "$(sed -n 's/^tpm=//p' "$REPO_ROOT/deps.lock")"
}

@test "a second install does not clone the plugin manager again" {
  "$REPO_ROOT/install.sh" --yes >/dev/null
  run "$REPO_ROOT/install.sh" --yes
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "git clone --quiet https://github.com/tmux-plugins/tpm.git"
  [ -d "$HOME/.tmux/plugins/tpm" ]
}

# The flavour is nekoshell's, not the user's, so it lives in its own file that
# the user's tmux.conf sources. A flavour switch rewrites that one line and
# leaves the config they edit alone.
@test "nekoshell-theme writes the flavour tmux reads" {
  "$REPO_ROOT/install.sh" --yes >/dev/null
  [ "$(cat "$HOME/.config/tmux/nekoshell-theme.conf")" = 'set -g @catppuccin_flavor "mocha"' ]
  "$REPO_ROOT/bin/nekoshell-theme" latte >/dev/null
  [ "$(cat "$HOME/.config/tmux/nekoshell-theme.conf")" = 'set -g @catppuccin_flavor "latte"' ]
  # The user's own tmux.conf is not touched by the switch.
  grep -q 'nekoshell-theme.conf' "$HOME/.config/tmux/tmux.conf"
}

@test "a dry-run install writes no nvim or tmux config" {
  run "$REPO_ROOT/install.sh" --dry-run --yes
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.config/nvim/init.lua" ]
  [ ! -e "$HOME/.config/tmux/tmux.conf" ]
  [ ! -e "$HOME/.config/tmux/nekoshell-theme.conf" ]
  [ ! -d "$HOME/.tmux/plugins/tpm" ]
}

@test "EDITOR prefers nvim when it is installed and falls back to vim" {
  stow_it
  mkdir -p "$HOME/fakebin"
  printf '#!/bin/sh\nexit 0\n' > "$HOME/fakebin/nvim"
  chmod +x "$HOME/fakebin/nvim"
  run zsh -c 'unset EDITOR
    PATH="$HOME/fakebin:/usr/bin:/bin"
    NEKOSHELL_CONFIG="$HOME/.config/nekoshell"
    source "$HOME/.config/nekoshell/zsh/env.zsh"
    echo "ED=$EDITOR"'
  [ "$status" -eq 0 ]
  [ "$(marker ED)" = "nvim" ]
  run zsh -c 'unset EDITOR
    PATH=/nonexistent
    NEKOSHELL_CONFIG="$HOME/.config/nekoshell"
    source "$HOME/.config/nekoshell/zsh/env.zsh"
    echo "ED=$EDITOR"'
  [ "$status" -eq 0 ]
  [ "$(marker ED)" = "vim" ]
}

# An EDITOR the user set themselves wins over both.
@test "EDITOR set in the environment is left alone" {
  stow_it
  mkdir -p "$HOME/fakebin"
  printf '#!/bin/sh\nexit 0\n' > "$HOME/fakebin/nvim"
  chmod +x "$HOME/fakebin/nvim"
  run zsh -c 'export EDITOR=emacs
    PATH="$HOME/fakebin:/usr/bin:/bin"
    NEKOSHELL_CONFIG="$HOME/.config/nekoshell"
    source "$HOME/.config/nekoshell/zsh/env.zsh"
    echo "ED=$EDITOR"'
  [ "$(marker ED)" = "emacs" ]
}

@test "vim and vi reach nvim when it is installed, and t is a tmux session" {
  stow_it
  mkdir -p "$HOME/fakebin"
  for t in nvim tmux; do
    printf '#!/bin/sh\nexit 0\n' > "$HOME/fakebin/$t"
    chmod +x "$HOME/fakebin/$t"
  done
  run zsh -c 'PATH="$HOME/fakebin:/usr/bin:/bin"
    source "$HOME/.config/nekoshell/zsh/aliases.zsh"
    echo "VIM=$(alias vim)"
    echo "VI=$(alias vi)"
    echo "T=$(alias t)"'
  [ "$status" -eq 0 ]
  assert_contains "$(marker VIM)" "nvim"
  assert_contains "$(marker VI)" "nvim"
  assert_contains "$(marker T)" "new-session -A -s main"
}

@test "vim stays vim when nvim is not installed" {
  stow_it
  run zsh -c 'PATH=/nonexistent
    source "$HOME/.config/nekoshell/zsh/aliases.zsh"
    echo "VIM=$(alias vim)"'
  [ "$status" -eq 0 ]
  [ "$(marker VIM)" = "" ]
}

# The lua files have to parse before nvim will do anything at all with them.
# Compile, never execute: init.lua clones lazy.nvim when it runs.
@test "every nvim lua file compiles" {
  if have_real luac; then
    for rel in $NVIM_FILES; do
      run env PATH="$NEKO_REAL_PATH" luac -p "$REPO_ROOT/templates/nvim/$rel"
      [ "$status" -eq 0 ]
    done
  elif have_real nvim; then
    for rel in $NVIM_FILES; do
      run env PATH="$NEKO_REAL_PATH" nvim --headless -u NONE -n \
        -c "lua assert(loadfile('$REPO_ROOT/templates/nvim/$rel'))" -c "quit"
      [ "$status" -eq 0 ]
    done
  else
    skip "neither luac nor nvim is installed"
  fi
}

# plugins.lua is a value, not a side effect: lazy.nvim is handed what it
# returns. A file that returns nothing leaves the editor with no plugins.
@test "plugins.lua returns a list of plugin specs naming catppuccin first" {
  if have_real lua; then
    run env PATH="$NEKO_REAL_PATH" lua -e "
      local spec = dofile('$REPO_ROOT/templates/nvim/lua/nekoshell/plugins.lua')
      assert(type(spec) == 'table')
      print(#spec, spec[1][1])"
  elif have_real nvim; then
    run env PATH="$NEKO_REAL_PATH" nvim --headless -u NONE -n -c "
      lua local s = dofile('$REPO_ROOT/templates/nvim/lua/nekoshell/plugins.lua')
      io.write(#s, ' ', s[1][1])" -c "quit"
  else
    skip "neither lua nor nvim is installed"
  fi
  assert_contains "$output" "catppuccin/nvim"
}

@test "the tmux config parses" {
  have_real tmux || skip "tmux is not installed"
  run env PATH="$NEKO_REAL_PATH" HOME="$HOME" \
    tmux -f "$REPO_ROOT/templates/tmux/tmux.conf" -L nekotest start-server ";" kill-server
  [ "$status" -eq 0 ]
}

# TPM is cloned by the installer and catppuccin/tmux only arrives when the user
# presses the install binding, so the config has to parse with neither present.
@test "the tmux config tolerates a missing plugin manager and a missing theme" {
  grep -q 'if-shell "test -f ~/.tmux/plugins/tpm/tpm" "run ~/.tmux/plugins/tpm/tpm"' \
    "$REPO_ROOT/templates/tmux/tmux.conf"
  # source-file -q: the flavour file is not there until the installer renders it.
  grep -q 'source-file -q ~/.config/tmux/nekoshell-theme.conf' \
    "$REPO_ROOT/templates/tmux/tmux.conf"
  have_real tmux || skip "tmux is not installed"
  run env PATH="$NEKO_REAL_PATH" HOME="$HOME" \
    tmux -f "$REPO_ROOT/templates/tmux/tmux.conf" -L nekotest2 start-server ";" kill-server
  [ "$status" -eq 0 ]
}

@test "the tmux config sets the C-a prefix and vim-style panes" {
  conf="$REPO_ROOT/templates/tmux/tmux.conf"
  grep -q '^set -g prefix C-a$' "$conf"
  grep -q '^bind C-a send-prefix$' "$conf"
  grep -q '^bind | split-window -h -c "#{pane_current_path}"$' "$conf"
  grep -q '^bind h select-pane -L$' "$conf"
  grep -q '^setw -g mode-keys vi$' "$conf"
  grep -q '^set -g mouse on$' "$conf"
}
