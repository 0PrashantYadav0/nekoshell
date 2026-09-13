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
  P="$REPO_ROOT/plugins/lazygit"
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

@test "add installs lazygit and links its config" {
  run "$NK" plugin add lazygit
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install lazygit"
  [ -L "$HOME/.config/lazygit/config.yml" ]
}

@test "the config asks for Nerd Fonts v3 and pages through delta" {
  CFG="$P/files/link/.config/lazygit/config.yml"
  grep -q 'nerdFontsVersion: "3"' "$CFG"
  grep -q 'pager: delta' "$CFG"
  # Catppuccin, not lazygit's own palette: the border colour is the mauve the
  # rest of the rig uses for what has focus.
  grep -q '#cba6f7' "$CFG"
}

@test "the config is valid YAML" {
  run python3 -c "
import sys
try:
    import yaml
except ImportError:
    sys.exit(9)
d = yaml.safe_load(open('$P/files/link/.config/lazygit/config.yml'))
print(sorted(d))"
  if [ "$status" -eq 9 ]; then skip "PyYAML not installed"; fi
  [ "$status" -eq 0 ]
  [ "$output" = "['git', 'gui']" ]
}

@test "doctor reports lazygit as a tool" {
  "$NK" plugin add lazygit >/dev/null
  run "$NK" doctor --plugin lazygit
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +tool: lazygit'
}

@test "remove unlinks the config and drops the plugin" {
  "$NK" plugin add lazygit >/dev/null
  run "$NK" plugin remove lazygit
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.config/lazygit/config.yml" ]
  [ "$(grep '^plugins' "$HOME/.config/nekoshell/nekoshell.toml")" = 'plugins = []' ]
}

@test "plugin.zsh aliases lg" {
  run zsh -o NO_GLOBAL_RCS -ic "source '$P/plugin.zsh'; echo \"LG=\$(alias lg)\""
  [ "$status" -eq 0 ]
  assert_contains "$(marker LG)" "lazygit"
}

@test "plugin.zsh is silent when lazygit is not installed" {
  run zsh -o NO_GLOBAL_RCS -ic "PATH=/nonexistent; source '$P/plugin.zsh'; alias lg >/dev/null 2>&1 && echo HAS_LG; echo DONE"
  [ "$status" -eq 0 ]
  assert_contains "$output" "DONE"
  assert_not_contains "$output" "HAS_LG"
  assert_not_contains "$output" "command not found"
}
