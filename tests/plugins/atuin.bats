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
  P="$REPO_ROOT/plugins/atuin"
}
teardown() { teardown_tmp_home; }

marker() { printf '%s\n' "$output" | sed -n "s/^$1=//p"; }

@test "plugin.toml is complete and the README has its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
}

@test "add installs atuin and links its config" {
  run "$NK" plugin add atuin
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install atuin"
  [ -L "$HOME/.config/atuin/config.toml" ]
}

@test "the config is valid TOML and stays offline" {
  run python3 -c "
import tomllib
d = tomllib.load(open('$P/files/link/.config/atuin/config.toml','rb'))
print(d['auto_sync'], d['update_check'])
print(d['style'], d['inline_height'], d['search_mode'], d['filter_mode_shell_up_key_binding'])"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "False False" ]
  [ "${lines[1]}" = "compact 20 fuzzy session" ]
}

@test "doctor reports atuin as a tool" {
  "$NK" plugin add atuin >/dev/null
  run "$NK" doctor --plugin atuin
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +tool: atuin'
  assert_not_contains "$output" "fail tool: atuin"
}

@test "remove unlinks the config and drops the plugin" {
  "$NK" plugin add atuin >/dev/null
  run "$NK" plugin remove atuin
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.config/atuin/config.toml" ]
  [ "$(grep '^plugins' "$HOME/.config/nekoshell/nekoshell.toml")" = 'plugins = []' ]
}

@test "atuin initialises without stealing the up arrow" {
  mkdir -p "$HOME/fakebin"
  printf '#!/usr/bin/env bash\necho "export NK_ATUIN_ARGS=\\"$*\\""\n' > "$HOME/fakebin/atuin"
  chmod +x "$HOME/fakebin/atuin"
  run zsh -o NO_GLOBAL_RCS -ic "PATH='$HOME/fakebin:/usr/bin:/bin'
    source '$P/late.zsh'
    echo \"ARGS=\$NK_ATUIN_ARGS\""
  [ "$status" -eq 0 ]
  [ "$(marker ARGS)" = "init zsh --disable-up-arrow" ]
}

# `fzf --zsh` rebinds Ctrl-R, so atuin has to be initialised after every
# plugin.zsh has run, whatever order the two plugins were added in. late.zsh is
# the core's hook for exactly that, and the zshrc sources it after plugin.zsh.
@test "the init lives in late.zsh, after every plugin.zsh" {
  [ -r "$P/late.zsh" ]
  [ ! -e "$P/plugin.zsh" ]
  grep -q 'atuin init zsh --disable-up-arrow' "$P/late.zsh"
}

@test "late.zsh is silent when atuin is not installed" {
  run zsh -o NO_GLOBAL_RCS -ic "PATH=/nonexistent; source '$P/late.zsh'; echo DONE"
  [ "$status" -eq 0 ]
  assert_contains "$output" "DONE"
  assert_not_contains "$output" "command not found"
}
