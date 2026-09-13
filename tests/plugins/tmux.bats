#!/usr/bin/env bats
load ../helpers

# tmux. The config is the user's own file (copied once, guarded), the flavour
# is nekoshell's and lives in files of its own that the config sources, and TPM
# is cloned at a pinned commit so a fresh machine gets the same plugins.

setup() {
  setup_tmp_home
  # The parse checks want the real tmux when the machine has one; the fake in
  # front of PATH answers for `command -v tmux` everywhere else.
  NEKO_REAL_PATH="$PATH"
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/tmux"
  CONF="$P/files/copy/.config/tmux/tmux.conf"
}
teardown() {
  # A probe server on its own socket, in case a test died before killing it.
  PATH="$NEKO_REAL_PATH" tmux -L nekoplugtest kill-server 2>/dev/null || true
  teardown_tmp_home
}

marker() { printf '%s\n' "$output" | sed -n "s/^$1=//p"; }

have_real() { PATH="$NEKO_REAL_PATH" command -v "$1" >/dev/null 2>&1; }

# set_flavour FLAVOUR: what a theme switch records, without rendering the rest.
set_flavour() {
  sed "s/^theme_resolved = .*/theme_resolved = \"$1\"/" "$HOME/.config/nekoshell/nekoshell.toml" > "$HOME/t.toml"
  mv "$HOME/t.toml" "$HOME/.config/nekoshell/nekoshell.toml"
}

@test "plugin.toml is complete and the README has its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  grep -q '^copy_guard *=' "$P/plugin.toml"
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
  grep -qF 'C-a I' "$P/README.md"
}

@test "add installs tmux and copies the config, unlinked" {
  run "$NK" plugin add tmux
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install tmux"
  [ -f "$HOME/.config/tmux/tmux.conf" ]
  [ ! -L "$HOME/.config/tmux/tmux.conf" ]
  grep -q 'set -g prefix C-a' "$HOME/.config/tmux/tmux.conf"
}

@test "a second add keeps your edits" {
  "$NK" plugin add tmux >/dev/null
  echo '# mine' >> "$HOME/.config/tmux/tmux.conf"
  "$NK" plugin add tmux >/dev/null
  grep -q '# mine' "$HOME/.config/tmux/tmux.conf"
}

# tmux 3.x prefers ~/.config/tmux/tmux.conf over ~/.tmux.conf, so ours would
# quietly win a config still in use.
@test "an existing ~/.tmux.conf keeps tmux out of the XDG path" {
  echo '# old tmux' > "$HOME/.tmux.conf"
  run "$NK" plugin add tmux
  [ "$status" -eq 0 ]
  assert_contains "$output" "tmux: .tmux.conf exists; left your config alone"
  [ "$(cat "$HOME/.tmux.conf")" = "# old tmux" ]
  [ ! -e "$HOME/.config/tmux/tmux.conf" ]
  # The flavour file is still written: it is inert until something sources it.
  [ "$(cat "$HOME/.config/tmux/nekoshell-theme.conf")" = 'set -g @catppuccin_flavor "mocha"' ]
}

@test "an existing XDG tmux.conf stops the copy too" {
  mkdir -p "$HOME/.config/tmux"
  echo '# old xdg tmux' > "$HOME/.config/tmux/tmux.conf"
  run "$NK" plugin add tmux
  [ "$status" -eq 0 ]
  assert_contains "$output" "tmux: .config/tmux/tmux.conf exists; left your config alone"
  [ "$(cat "$HOME/.config/tmux/tmux.conf")" = "# old xdg tmux" ]
}

@test "the plugin manager is cloned at the pinned commit, into the XDG path" {
  sha="$(sed -n 's/^TPM_SHA="\([0-9a-f]*\)".*/\1/p' "$P/install.sh")"
  printf '%s\n' "$sha" | grep -q '^[0-9a-f]\{40\}$'
  run "$NK" plugin add tmux
  [ "$status" -eq 0 ]
  [ -d "$HOME/.config/tmux/plugins/tpm" ]
  [ ! -e "$HOME/.tmux/plugins/tpm" ]
  assert_contains "$output" "$sha"
}

@test "a second add does not clone the plugin manager again" {
  "$NK" plugin add tmux >/dev/null
  run "$NK" plugin add tmux
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "clone --quiet https://github.com/tmux-plugins/tpm.git"
  [ -d "$HOME/.config/tmux/plugins/tpm" ]
}

# The network is only worth touching when there is something to get: a clone
# that already holds the pinned commit is the state every add after the first
# one is in.
@test "a clone that already holds the pinned commit is not fetched" {
  "$NK" plugin add tmux >/dev/null
  run env FAKE_GIT_HAS_COMMIT=1 "$NK" plugin add tmux
  [ "$status" -eq 0 ]
  # the precise flag, not the bare word: "fastfetch" contains "fetch"
  assert_not_contains "$output" "fetch --quiet"
}

# Offline is not broken: TPM manages plugins perfectly well at whatever commit
# it is already on, so a failed fetch is a note and the add carries on.
@test "a fetch that fails warns and the add still succeeds" {
  "$NK" plugin add tmux >/dev/null
  run env FAKE_GIT_FAIL_FETCH=1 "$NK" plugin add tmux
  [ "$status" -eq 0 ]
  assert_contains "$output" "tmux: could not fetch TPM; keeping what is there"
  assert_contains "$output" "tmux enabled"
  [ -d "$HOME/.config/tmux/plugins/tpm" ]
}

# A plugins/tpm that is a directory but not a checkout fails every git command
# that reaches into it, the checkout included. It must still leave the plugin
# enabled and the config copied.
@test "a tpm directory that is not a checkout warns and the add still succeeds" {
  mkdir -p "$HOME/.config/tmux/plugins/tpm"
  echo 'not a checkout' > "$HOME/.config/tmux/plugins/tpm/notes.txt"
  run env FAKE_GIT_NOT_REPO=1 "$NK" plugin add tmux
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "clone --quiet"
  assert_contains "$output" "tmux: could not fetch TPM; keeping what is there"
  assert_contains "$output" "tmux: could not check out TPM at"
  assert_contains "$output" "tmux enabled"
  [ -f "$HOME/.config/tmux/tmux.conf" ]
  [ "$(grep '^plugins' "$HOME/.config/nekoshell/nekoshell.toml")" = 'plugins = ["tmux"]' ]
}

# A clone in the wrong place is never read, and TPM fetches itself again with
# no pin at all. The config and the install hook have to name the same place.
@test "the config and the install hook agree on where the plugins live" {
  grep -q 'set-environment -g TMUX_PLUGIN_MANAGER_PATH "~/.config/tmux/plugins/"' "$CONF"
  grep -q 'TPM_DIR="\$HOME/.config/tmux/plugins/tpm"' "$P/install.sh"
}

# The flavour is nekoshell's, not the user's, so it lives in its own file that
# the config sources. A flavour switch rewrites that file and leaves the one
# they edit alone.
@test "the theme hook writes the flavour tmux reads, and a switch rewrites it" {
  "$NK" plugin add tmux >/dev/null
  [ "$(cat "$HOME/.config/tmux/nekoshell-theme.conf")" = 'set -g @catppuccin_flavor "mocha"' ]
  echo '# mine' >> "$HOME/.config/tmux/tmux.conf"
  set_flavour latte
  "$NK" plugin add tmux >/dev/null
  [ "$(cat "$HOME/.config/tmux/nekoshell-theme.conf")" = 'set -g @catppuccin_flavor "latte"' ]
  grep -q '# mine' "$HOME/.config/tmux/tmux.conf"
}

# Later plugins drop nekoshell-truecolor.conf and nekoshell-statusbar.conf next
# to the theme file, so the config sources the whole set rather than one name.
@test "the config sources every nekoshell-*.conf, not just the theme one" {
  grep -q "run-shell 'for f in ~/.config/tmux/nekoshell-\*.conf; do \[ -r \"\$f\" \] && tmux source-file \"\$f\"; done; true'" "$CONF"
  ! grep -q '^source-file -q ~/.config/tmux/nekoshell-theme.conf$' "$CONF"
}

# With no generated file yet, the loop ends on a false `[ -r ]`; without the
# trailing `true` tmux reports that as a failed run-shell on a fresh install.
@test "the sourcing loop ends true, so a fresh config reports nothing" {
  have_real tmux || skip "tmux is not installed"
  [ ! -e "$HOME/.config/tmux/nekoshell-theme.conf" ]
  run env PATH="$NEKO_REAL_PATH" HOME="$HOME" \
    tmux -f "$CONF" -L nekoplugtest start-server ";" kill-server
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "doctor reports tmux" {
  "$NK" plugin add tmux >/dev/null
  run "$NK" doctor --plugin tmux
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +tool: tmux'
}

@test "doctor fails when tmux is missing" {
  "$NK" plugin add tmux >/dev/null
  run env PATH="/usr/bin:/bin" "$NK" doctor --plugin tmux
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +tool: tmux'
}

@test "remove drops the plugin and leaves the copied config alone" {
  "$NK" plugin add tmux >/dev/null
  run "$NK" plugin remove tmux
  [ "$status" -eq 0 ]
  [ -f "$HOME/.config/tmux/tmux.conf" ]
  [ "$(grep '^plugins' "$HOME/.config/nekoshell/nekoshell.toml")" = 'plugins = []' ]
}

@test "plugin.zsh gives t a persistent main session" {
  run zsh -o NO_GLOBAL_RCS -ic "PATH='$REPO_ROOT/tests/fakes:/usr/bin:/bin'
    source '$P/plugin.zsh'
    echo \"T=\$(alias t)\""
  [ "$status" -eq 0 ]
  assert_contains "$(marker T)" "new-session -A -s main"
}

@test "plugin.zsh is silent when tmux is not installed" {
  run zsh -o NO_GLOBAL_RCS -ic "PATH=/nonexistent
    source '$P/plugin.zsh'
    alias t >/dev/null 2>&1 && echo HAS_T
    echo DONE"
  [ "$status" -eq 0 ]
  assert_contains "$output" "DONE"
  assert_not_contains "$output" "HAS_T"
  assert_not_contains "$output" "command not found"
}

@test "the shipped config parses" {
  have_real tmux || skip "tmux is not installed"
  run env PATH="$NEKO_REAL_PATH" HOME="$HOME" \
    tmux -f "$CONF" -L nekoplugtest start-server ";" kill-server
  [ "$status" -eq 0 ]
}

# TPM is cloned by the install hook and catppuccin/tmux only arrives when the
# user presses the install binding, so the config has to parse with neither.
@test "the config tolerates a missing plugin manager and a missing theme" {
  grep -q 'if-shell "test -f ~/.config/tmux/plugins/tpm/tpm" "run ~/.config/tmux/plugins/tpm/tpm"' "$CONF"
  grep -q 'if-shell "test -f ~/.config/tmux/plugins/tmux/catppuccin.tmux"' "$CONF"
  have_real tmux || skip "tmux is not installed"
  run env PATH="$NEKO_REAL_PATH" HOME="$HOME" \
    tmux -f "$CONF" -L nekoplugtest start-server ";" kill-server
  [ "$status" -eq 0 ]
}

@test "the config sets the C-a prefix and vim-style panes" {
  grep -q '^set -g prefix C-a$' "$CONF"
  grep -q '^bind C-a send-prefix$' "$CONF"
  grep -q '^bind | split-window -h -c "#{pane_current_path}"$' "$CONF"
  grep -q '^bind h select-pane -L$' "$CONF"
  grep -q '^setw -g mode-keys vi$' "$CONF"
  grep -q '^set -g mouse on$' "$CONF"
}
