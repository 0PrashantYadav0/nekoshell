#!/usr/bin/env bats
load ../helpers
setup() {
  setup_tmp_home
  export NEKOSHELL_ROOT="$REPO_ROOT"
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  for l in paths log brew; do source "$REPO_ROOT/core/lib/$l.sh"; done
  export FAKE_BREW_INSTALLED="eza bat"
}
teardown() { teardown_tmp_home; }

@test "brew_has asks brew list" {
  brew_has eza; ! brew_has fzf
}
# Not `run`: log.sh (sourced above) defines its own run(), which shadows
# bats' run() for the rest of each test process and would leave $output
# empty. Plain command substitution captures the functions' stdout instead.
@test "brew_install only installs what is missing, in one call" {
  output="$(brew_install eza fzf zoxide)"
  assert_contains "$output" "brew install fzf zoxide"
  assert_not_contains "$output" "install eza"
}
@test "brew_install with nothing missing runs nothing" {
  output="$(brew_install eza bat)"
  assert_not_contains "$output" "brew install"
}
@test "brew_cask_install and brew_tap" {
  export FAKE_BREW_CASKS="iterm2"
  output="$(brew_cask_install iterm2 kitty)"; assert_contains "$output" "brew install --cask kitty"; assert_not_contains "$output" "cask iterm2"
  output="$(brew_tap nikitabobko/tap)"; assert_contains "$output" "brew tap nikitabobko/tap"
}
