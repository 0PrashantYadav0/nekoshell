#!/usr/bin/env bats
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/modern-cli"
}
teardown() { teardown_tmp_home; }

@test "plugin.toml is complete and the README has its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
}

@test "add installs the tools and links the configs" {
  run "$NK" plugin add modern-cli
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install eza bat fd ripgrep zoxide git-delta"
  [ -L "$HOME/.config/bat/config" ]
  [ -L "$HOME/.config/bat/themes/Catppuccin Mocha.tmTheme" ]
  [ -L "$HOME/.config/nekoshell/git/delta.gitconfig" ]
}

@test "add writes the delta include into ~/.gitconfig exactly once" {
  "$NK" plugin add modern-cli >/dev/null
  grep -q 'delta.gitconfig' "$HOME/.gitconfig"
  [ "$(grep -c 'delta.gitconfig' "$HOME/.gitconfig")" -eq 1 ]
  "$NK" plugin add modern-cli >/dev/null
  [ "$(grep -c 'delta.gitconfig' "$HOME/.gitconfig")" -eq 1 ]
}

@test "add keeps an existing ~/.gitconfig and appends to it" {
  printf '[user]\n\tname = Someone\n' > "$HOME/.gitconfig"
  "$NK" plugin add modern-cli >/dev/null
  grep -q 'name = Someone' "$HOME/.gitconfig"
  grep -q 'delta.gitconfig' "$HOME/.gitconfig"
}

@test "the theme hook rebuilds bat's theme cache" {
  run "$NK" plugin add modern-cli
  assert_contains "$output" "bat cache --build"
}

@test "doctor rows: one per tool, plus the bat theme cache" {
  "$NK" plugin add modern-cli >/dev/null
  run "$NK" doctor --plugin modern-cli
  [ "$status" -eq 0 ]
  for t in eza bat fd rg zoxide delta; do
    assert_matches "$output" "ok +tool: $t"
  done
  assert_matches "$output" 'ok +bat theme +Catppuccin Mocha'
}

@test "doctor fails a missing tool and warns on a stale bat cache" {
  "$NK" plugin add modern-cli >/dev/null
  mkdir -p "$HOME/fakebin"
  for t in eza bat fd rg zoxide delta; do
    [ "$t" = "bat" ] && continue
    printf '#!/usr/bin/env bash\necho "%s $*"\n' "$t" > "$HOME/fakebin/$t"
    chmod +x "$HOME/fakebin/$t"
  done
  printf '#!/usr/bin/env bash\nexit 0\n' > "$HOME/fakebin/bat"
  chmod +x "$HOME/fakebin/bat"
  rm "$HOME/fakebin/eza"
  run env PATH="$HOME/fakebin:/usr/bin:/bin" "$NK" doctor --plugin modern-cli
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +tool: eza'
  assert_matches "$output" 'warn +bat theme +run: bat cache --build'
}

@test "remove unlinks the configs and drops the gitconfig include" {
  "$NK" plugin add modern-cli >/dev/null
  run "$NK" plugin remove modern-cli
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.config/bat/config" ]
  [ ! -e "$HOME/.config/nekoshell/git/delta.gitconfig" ]
  ! grep -q 'delta.gitconfig' "$HOME/.gitconfig"
}

@test "plugin.zsh aliases ls and cat and starts zoxide" {
  "$NK" plugin add modern-cli >/dev/null
  run zsh -o NO_GLOBAL_RCS -ic "source '$P/plugin.zsh'
    echo \"LS=\$(alias ls)\"
    echo \"CAT=\$(alias cat)\"
    echo \"LT=\$(alias lt)\""
  [ "$status" -eq 0 ]
  assert_contains "$output" "eza --icons --group-directories-first"
  assert_contains "$output" "bat --paging=never"
  assert_contains "$output" "eza --icons --tree --level=2"
}

@test "plugin.zsh is silent when none of the tools are installed" {
  run zsh -o NO_GLOBAL_RCS -ic "PATH=/nonexistent; source '$P/plugin.zsh'; echo DONE"
  [ "$status" -eq 0 ]
  assert_contains "$output" "DONE"
}
