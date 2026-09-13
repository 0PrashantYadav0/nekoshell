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
  P="$REPO_ROOT/plugins/fzf"
}
teardown() { teardown_tmp_home; }

# Read values back by marker instead of by line number: an interactive shell
# prints lines of its own and the index is not ours to predict.
marker() { printf '%s\n' "$output" | sed -n "s/^$1=//p"; }

@test "plugin.toml is complete and the README has its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
}

@test "add installs fzf" {
  run "$NK" plugin add fzf
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install fzf"
}

@test "doctor reports fzf as a tool" {
  "$NK" plugin add fzf >/dev/null
  run "$NK" doctor --plugin fzf
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +tool: fzf'
}

@test "remove drops the plugin" {
  "$NK" plugin add fzf >/dev/null
  run "$NK" plugin remove fzf
  [ "$status" -eq 0 ]
  [ "$(grep '^plugins' "$HOME/.config/nekoshell/nekoshell.toml")" = 'plugins = []' ]
}

@test "fzf.zsh parses as zsh" {
  run zsh -n "$P/fzf.zsh"
  [ "$status" -eq 0 ]
}

@test "plugin.zsh installs the key bindings and sets a preview for each of the three" {
  "$NK" plugin add fzf >/dev/null
  run zsh -o NO_GLOBAL_RCS -ic "source '$P/plugin.zsh'
    echo \"CTRL_T=\$FZF_CTRL_T_OPTS\"
    echo \"ALT_C=\$FZF_ALT_C_OPTS\"
    echo \"CTRL_R=\$FZF_CTRL_R_OPTS\""
  [ "$status" -eq 0 ]
  assert_contains "$(marker CTRL_T)" 'bat --color=always'
  assert_contains "$(marker CTRL_T)" '--preview-window=right:60%'
  assert_contains "$(marker ALT_C)" 'eza --tree --level=2'
  assert_contains "$(marker CTRL_R)" '--preview-window=down:3:wrap'
}

# fd is the only one of these that changes what fzf lists rather than how it
# previews, so it has to be conditional: without fd, fzf's own default walk.
@test "FZF_DEFAULT_COMMAND is set only when fd is on PATH" {
  run zsh -o NO_GLOBAL_RCS -ic "source '$P/fzf.zsh'; echo \"CMD=\$FZF_DEFAULT_COMMAND\""
  [ "$(marker CMD)" = "fd --type f --hidden --follow --exclude .git" ]
  run zsh -o NO_GLOBAL_RCS -ic "PATH=/nonexistent; source '$P/fzf.zsh'; echo \"CMD=\${FZF_DEFAULT_COMMAND-unset}\""
  [ "$(marker CMD)" = "unset" ]
}

@test "fzf-tab previews directories and reuses the themed fzf defaults" {
  run zsh -o NO_GLOBAL_RCS -ic "source '$P/fzf.zsh'
    zstyle -s ':fzf-tab:complete:cd:*' fzf-preview v; echo \"PREVIEW=\$v\"
    zstyle -s ':fzf-tab:*' use-fzf-default-opts w; echo \"DEFAULTS=\$w\""
  assert_contains "$(marker PREVIEW)" 'eza --icons --color=always -1 '
  [ "$(marker DEFAULTS)" = "yes" ]
}

@test "plugin.zsh is silent when fzf is not installed" {
  run zsh -o NO_GLOBAL_RCS -ic "PATH=/nonexistent; source '$P/plugin.zsh'; echo DONE"
  [ "$status" -eq 0 ]
  assert_contains "$output" "DONE"
  assert_not_contains "$output" "command not found"
}
