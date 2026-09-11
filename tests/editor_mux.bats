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
teardown() {
  # A probe server on its own socket, in case a test died before killing it.
  PATH="$NEKO_REAL_PATH" tmux -L nekotest3 kill-server 2>/dev/null || true
  teardown_tmp_home
}

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

# A config of someone else's is theirs whole. nekoshell copies its own in only
# when there is nothing there at all, and says so when it backs off, because a
# silent skip looks exactly like a silent overwrite from the outside.
@test "an existing Neovim config is left alone, whole" {
  mkdir -p "$HOME/.config/nvim/lua/myplug" "$HOME/.config/nvim/after/plugin"
  echo 'old init' > "$HOME/.config/nvim/init.lua"
  echo 'old plug' > "$HOME/.config/nvim/lua/myplug/x.lua"
  echo 'old after' > "$HOME/.config/nvim/after/plugin/mine.lua"
  run "$REPO_ROOT/install.sh" --yes
  [ "$status" -eq 0 ]
  assert_contains "$output" "existing Neovim config found at ~/.config/nvim; leaving it alone"
  [ "$(cat "$HOME/.config/nvim/init.lua")" = "old init" ]
  [ "$(cat "$HOME/.config/nvim/lua/myplug/x.lua")" = "old plug" ]
  [ "$(cat "$HOME/.config/nvim/after/plugin/mine.lua")" = "old after" ]
  # Not one file of ours, and not even the directory they would live in.
  [ ! -e "$HOME/.config/nvim/lua/nekoshell" ]
  # Nothing was replaced, so there was nothing to back up: on this HOME the
  # nvim files are the only thing the installer could have taken.
  [ ! -e "$HOME/.local/share/nekoshell/backup" ]
}

# init.vim is the trap: Neovim reads init.lua in preference to it, so dropping
# ours in would silence a vimscript config without replacing a single file.
@test "an init.vim config is left alone and never shadowed by an init.lua" {
  mkdir -p "$HOME/.config/nvim"
  echo '" old vimscript' > "$HOME/.config/nvim/init.vim"
  run "$REPO_ROOT/install.sh" --yes
  [ "$status" -eq 0 ]
  assert_contains "$output" "existing Neovim config found at ~/.config/nvim"
  [ "$(cat "$HOME/.config/nvim/init.vim")" = '" old vimscript' ]
  [ ! -e "$HOME/.config/nvim/init.lua" ]
  [ ! -e "$HOME/.config/nvim/lua" ]
}

# Same trap, the other way round: tmux 3.x prefers ~/.config/tmux/tmux.conf
# over ~/.tmux.conf, so ours would quietly win a config still in use.
@test "an existing ~/.tmux.conf keeps tmux out of the XDG path" {
  echo '# old tmux' > "$HOME/.tmux.conf"
  run "$REPO_ROOT/install.sh" --yes
  [ "$status" -eq 0 ]
  assert_contains "$output" "existing tmux config found"
  [ "$(cat "$HOME/.tmux.conf")" = "# old tmux" ]
  [ ! -e "$HOME/.config/tmux/tmux.conf" ]
  # The flavour file is still written: it is inert until something sources it.
  [ "$(cat "$HOME/.config/tmux/nekoshell-theme.conf")" = 'set -g @catppuccin_flavor "mocha"' ]
}

@test "a fresh HOME gets the whole nvim tree, not a handful of files" {
  "$REPO_ROOT/install.sh" --yes >/dev/null
  for rel in $NVIM_FILES; do
    [ -f "$HOME/.config/nvim/$rel" ]
  done
  [ -d "$HOME/.config/nvim/lua/nekoshell" ]
  [ -f "$HOME/.config/tmux/tmux.conf" ]
}

@test "the tmux plugin manager is cloned at the pinned commit" {
  grep -q '^tpm=[0-9a-f]\{40\}$' "$REPO_ROOT/deps.lock"
  run "$REPO_ROOT/install.sh" --yes
  [ "$status" -eq 0 ]
  # The XDG path, because that is the one TPM itself uses next to this config.
  [ -d "$HOME/.config/tmux/plugins/tpm" ]
  [ ! -e "$HOME/.tmux/plugins/tpm" ]
  assert_contains "$output" "$(sed -n 's/^tpm=//p' "$REPO_ROOT/deps.lock")"
}

# A clone in the wrong place is never read, and TPM fetches itself again with no
# pin at all. The config and the installer have to name the same directory.
@test "the config and the installer agree on where the plugins live" {
  grep -q 'set-environment -g TMUX_PLUGIN_MANAGER_PATH "~/.config/tmux/plugins/"' \
    "$REPO_ROOT/templates/tmux/tmux.conf"
  grep -q 'TPM_DIR="\$HOME/.config/tmux/plugins/tpm"' "$REPO_ROOT/install.sh"
}

@test "a deps.lock without a usable tpm commit stops before the backup step" {
  mkdir -p "$HOME/checkout"
  for d in lib templates data stow iterm2 bin; do cp -R "$REPO_ROOT/$d" "$HOME/checkout/"; done
  cp "$REPO_ROOT/install.sh" "$REPO_ROOT/Brewfile" "$HOME/checkout/"
  sed 's/^tpm=.*/tpm=/' "$REPO_ROOT/deps.lock" > "$HOME/checkout/deps.lock"
  run "$HOME/checkout/install.sh" --yes
  [ "$status" -ne 0 ]
  assert_contains "$output" "deps.lock has no valid commit for tpm"
  # Before the backup step means nothing of theirs has moved yet.
  [ ! -d "$HOME/.local/share/nekoshell/backup" ]
}

@test "a second install does not clone the plugin manager again" {
  "$REPO_ROOT/install.sh" --yes >/dev/null
  run "$REPO_ROOT/install.sh" --yes
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "git clone --quiet https://github.com/tmux-plugins/tpm.git"
  [ -d "$HOME/.config/tmux/plugins/tpm" ]
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
  [ ! -d "$HOME/.config/tmux/plugins/tpm" ]
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
  grep -q 'if-shell "test -f ~/.config/tmux/plugins/tpm/tpm" "run ~/.config/tmux/plugins/tpm/tpm"' \
    "$REPO_ROOT/templates/tmux/tmux.conf"
  grep -q 'if-shell "test -f ~/.config/tmux/plugins/tmux/catppuccin.tmux"' \
    "$REPO_ROOT/templates/tmux/tmux.conf"
  # source-file -q: the flavour file is not there until the installer renders it.
  grep -q 'source-file -q ~/.config/tmux/nekoshell-theme.conf' \
    "$REPO_ROOT/templates/tmux/tmux.conf"
  have_real tmux || skip "tmux is not installed"
  run env PATH="$NEKO_REAL_PATH" HOME="$HOME" \
    tmux -f "$REPO_ROOT/templates/tmux/tmux.conf" -L nekotest2 start-server ";" kill-server
  [ "$status" -eq 0 ]
}

# The editor follows the flavour by reading the variable theme.zsh exports.
# Renaming it in one place and not the other is a silent mocha-forever bug.
@test "the nvim colourscheme reads NEKOSHELL_THEME with a mocha fallback" {
  grep -q 'vim.env.NEKOSHELL_THEME' "$REPO_ROOT/templates/nvim/lua/nekoshell/plugins.lua"
  grep -q 'flavour = "mocha"' "$REPO_ROOT/templates/nvim/lua/nekoshell/plugins.lua"
  grep -q 'NEKOSHELL_THEME' "$REPO_ROOT/lib/theme.sh"
}

# tmux reads TMUX_PLUGIN_MANAGER_PATH out of the global environment, so ask a
# real server what it ended up with rather than trusting the grep above.
@test "a live tmux server takes the plugin path from the config" {
  have_real tmux || skip "tmux is not installed"
  # Detached, on a socket of its own, in the throwaway HOME: nothing here can
  # reach the terminal running the tests. A server with no session exits at
  # once, so the probe holds one open with a sleep.
  env PATH="$NEKO_REAL_PATH" HOME="$HOME" \
    tmux -f "$REPO_ROOT/templates/tmux/tmux.conf" -L nekotest3 \
    new-session -d -s probe -- sh -c 'sleep 60'
  run env PATH="$NEKO_REAL_PATH" HOME="$HOME" \
    tmux -L nekotest3 show-environment -g TMUX_PLUGIN_MANAGER_PATH
  env PATH="$NEKO_REAL_PATH" HOME="$HOME" tmux -L nekotest3 kill-server
  # tmux expands the ~ against the HOME the server started in, so the value
  # that comes back is absolute.
  [ "$output" = "TMUX_PLUGIN_MANAGER_PATH=$HOME/.config/tmux/plugins/" ]
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
