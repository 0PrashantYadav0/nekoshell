#!/usr/bin/env bats
load ../helpers

# Neovim's config is the user's own file: copied once, never linked, never
# overwritten. A config that is already there stops the copy whole (copy_guard),
# because half of ours layered under someone's init.lua is worse than none.

setup() {
  setup_tmp_home
  # The parse checks want the real luac/lua/nvim when the machine has them, so
  # the machine's own PATH is kept around behind the fakes.
  NEKO_REAL_PATH="$PATH"
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/nvim"
  COPY="$P/files/copy/.config/nvim"
}
teardown() { teardown_tmp_home; }

marker() { printf '%s\n' "$output" | sed -n "s/^$1=//p"; }

# have_real TOOL: TOOL is really installed, rather than being one of the fakes.
have_real() { PATH="$NEKO_REAL_PATH" command -v "$1" >/dev/null 2>&1; }

NVIM_FILES="init.lua lua/nekoshell/options.lua lua/nekoshell/keymaps.lua lua/nekoshell/plugins.lua"

@test "plugin.toml is complete and the README has its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  grep -q '^copy_guard *=' "$P/plugin.toml"
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
}

@test "add installs neovim and copies the whole tree, unlinked" {
  run "$NK" plugin add nvim
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install neovim"
  for rel in $NVIM_FILES; do
    [ -f "$HOME/.config/nvim/$rel" ]
    [ ! -L "$HOME/.config/nvim/$rel" ]
  done
  [ -d "$HOME/.config/nvim/lua/nekoshell" ]
  grep -q 'nekoshell.options' "$HOME/.config/nvim/init.lua"
  grep -q 'catppuccin' "$HOME/.config/nvim/lua/nekoshell/plugins.lua"
}

@test "a second add keeps your edits" {
  "$NK" plugin add nvim >/dev/null
  echo '-- mine' >> "$HOME/.config/nvim/init.lua"
  echo '-- also mine' >> "$HOME/.config/nvim/lua/nekoshell/keymaps.lua"
  "$NK" plugin add nvim >/dev/null
  grep -q -- '-- mine' "$HOME/.config/nvim/init.lua"
  grep -q -- '-- also mine' "$HOME/.config/nvim/lua/nekoshell/keymaps.lua"
}

# A config of someone else's is theirs whole, and the skip is loud: a silent
# one looks exactly like a silent overwrite from the outside.
@test "an existing init.lua stops the copy, whole and loudly" {
  mkdir -p "$HOME/.config/nvim/lua/myplug"
  echo 'old init' > "$HOME/.config/nvim/init.lua"
  echo 'old plug' > "$HOME/.config/nvim/lua/myplug/x.lua"
  run "$NK" plugin add nvim
  [ "$status" -eq 0 ]
  assert_contains "$output" "nvim: .config/nvim/init.lua exists; left your config alone"
  [ "$(cat "$HOME/.config/nvim/init.lua")" = "old init" ]
  [ "$(cat "$HOME/.config/nvim/lua/myplug/x.lua")" = "old plug" ]
  [ ! -e "$HOME/.config/nvim/lua/nekoshell" ]
}

# init.vim is the trap: Neovim reads init.lua in preference to it, so dropping
# ours in would silence a vimscript config without replacing a single file.
@test "an init.vim config is left alone and never shadowed by an init.lua" {
  mkdir -p "$HOME/.config/nvim"
  echo '" old vimscript' > "$HOME/.config/nvim/init.vim"
  run "$NK" plugin add nvim
  [ "$status" -eq 0 ]
  assert_contains "$output" "nvim: .config/nvim/init.vim exists; left your config alone"
  [ "$(cat "$HOME/.config/nvim/init.vim")" = '" old vimscript' ]
  [ ! -e "$HOME/.config/nvim/init.lua" ]
  [ ! -e "$HOME/.config/nvim/lua" ]
}

@test "doctor reports neovim" {
  "$NK" plugin add nvim >/dev/null
  run "$NK" doctor --plugin nvim
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +tool: nvim'
}

@test "doctor fails when neovim is missing" {
  "$NK" plugin add nvim >/dev/null
  run env PATH="/usr/bin:/bin" "$NK" doctor --plugin nvim
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +tool: nvim'
}

@test "remove drops the plugin and leaves the copied config alone" {
  "$NK" plugin add nvim >/dev/null
  run "$NK" plugin remove nvim
  [ "$status" -eq 0 ]
  [ -f "$HOME/.config/nvim/init.lua" ]
  [ "$(grep '^plugins' "$HOME/.config/nekoshell/nekoshell.toml")" = 'plugins = []' ]
}

@test "plugin.zsh aliases vim and vi and sets EDITOR" {
  run zsh -o NO_GLOBAL_RCS -ic "PATH='$REPO_ROOT/tests/fakes:/usr/bin:/bin'
    source '$P/plugin.zsh'
    echo \"VIM=\$(alias vim)\"
    echo \"VI=\$(alias vi)\"
    echo \"ED=\$EDITOR\""
  [ "$status" -eq 0 ]
  assert_contains "$(marker VIM)" "nvim"
  assert_contains "$(marker VI)" "nvim"
  [ "$(marker ED)" = "nvim" ]
}

@test "plugin.zsh is silent when neovim is not installed" {
  run zsh -o NO_GLOBAL_RCS -ic "PATH=/nonexistent
    unset EDITOR
    source '$P/plugin.zsh'
    alias vim >/dev/null 2>&1 && echo HAS_VIM
    [[ -n \"\$EDITOR\" ]] && echo HAS_EDITOR
    echo DONE"
  [ "$status" -eq 0 ]
  assert_contains "$output" "DONE"
  assert_not_contains "$output" "HAS_VIM"
  assert_not_contains "$output" "HAS_EDITOR"
  assert_not_contains "$output" "command not found"
}

# The lua files have to parse before nvim will do anything at all with them.
# Compile, never execute: init.lua clones lazy.nvim when it runs.
@test "every nvim lua file compiles" {
  if have_real luac; then
    for rel in $NVIM_FILES; do
      run env PATH="$NEKO_REAL_PATH" luac -p "$COPY/$rel"
      [ "$status" -eq 0 ]
    done
  elif have_real nvim; then
    for rel in $NVIM_FILES; do
      run env PATH="$NEKO_REAL_PATH" nvim --headless -u NONE -n \
        -c "lua assert(loadfile('$COPY/$rel'))" -c "quit"
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
      local spec = dofile('$COPY/lua/nekoshell/plugins.lua')
      assert(type(spec) == 'table')
      print(#spec, spec[1][1])"
  elif have_real nvim; then
    run env PATH="$NEKO_REAL_PATH" nvim --headless -u NONE -n -c "
      lua local s = dofile('$COPY/lua/nekoshell/plugins.lua')
      io.write(#s, ' ', s[1][1])" -c "quit"
  else
    skip "neither lua nor nvim is installed"
  fi
  assert_contains "$output" "catppuccin/nvim"
}

# The editor follows the flavour by reading the variable theme.zsh exports.
@test "the nvim colourscheme reads NEKOSHELL_THEME with a mocha fallback" {
  grep -q 'vim.env.NEKOSHELL_THEME' "$COPY/lua/nekoshell/plugins.lua"
  grep -q 'flavour = "mocha"' "$COPY/lua/nekoshell/plugins.lua"
}

# A statusbar plugin reads the pane title to show what is running in it, and
# an nvim that never sets one leaves it showing the shell forever.
@test "options.lua names the terminal title after the open file" {
  grep -q '^vim.opt.title = true$' "$COPY/lua/nekoshell/options.lua"
  grep -q '^vim.opt.titlestring = "nvim: %t"$' "$COPY/lua/nekoshell/options.lua"
}
