#!/usr/bin/env bats
load ../helpers
setup() {
  setup_tmp_home
  export NEKOSHELL_ROOT="$REPO_ROOT"
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  for l in paths log backup config link brew plugin terminal; do source "$REPO_ROOT/core/lib/$l.sh"; done
  mkdir -p "$NEKOSHELL_CONFIG" "$NEKOSHELL_CACHE"
  toml_set "$NEKOSHELL_TOML" root "$NEKOSHELL_ROOT"
  toml_set "$NEKOSHELL_TOML" terminal fake
  toml_set "$NEKOSHELL_TOML" theme_resolved mocha
  toml_set_list "$NEKOSHELL_TOML" plugins
  printf 'core/plugin\n' > "$HOME/core-plugins.txt"; export NEKOSHELL_CORE_ANTIDOTE="$HOME/core-plugins.txt"
  backup_begin
}
teardown() { teardown_tmp_home; }

# Not bats `run`: log.sh (sourced above) defines its own run(), which shadows
# bats' run() for the rest of each test process and would leave $output
# empty. Plain command substitution captures stdout/stderr and exit status
# instead.

@test "plugin_all lists fixture plugins sorted; plugin_meta reads toml" {
  [ "$(plugin_all | tr '\n' ' ')" = "broken clash demo fakeart fakeart2 fakeplayer flaky-doctor guarded kitty-only needs-demo otherplayer " ]
  [ "$(plugin_meta demo summary)" = "A fixture plugin" ]
  [ "$(plugin_meta_list demo requires)" = "eza" ]
  plugin_exists demo; ! plugin_exists nope
}
@test "plugin_add installs deps, links, copies, runs hooks, records, regenerates antidote" {
  status=0
  output="$(plugin_add demo 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install eza"
  [ -L "$HOME/.config/demo/conf" ]
  [ -f "$HOME/.config/demo/mine.conf" ] && [ ! -L "$HOME/.config/demo/mine.conf" ]
  grep -q "demo install FLAVOR=mocha PLUGIN_DIR=$NEKOSHELL_PLUGINS_DIR/demo" "$NEKOSHELL_CACHE/hooks.log"
  plugin_enabled demo
  [ "$(config_list plugins)" = "demo" ]
  grep -q '^core/plugin$' "$NEKOSHELL_CONFIG/antidote.txt"
  grep -q '^zsh-users/zsh-example$' "$NEKOSHELL_CONFIG/antidote.txt"
  assert_contains "$output" "ok   demo"
}
@test "plugin_add is idempotent" {
  plugin_add demo >/dev/null
  status=0
  output="$(plugin_add demo 2>&1)" || status=$?
  [ "$status" -eq 0 ]; [ "$(config_list plugins)" = "demo" ]
  [ "$(grep -c 'demo install' "$NEKOSHELL_CACHE/hooks.log")" -eq 2 ]
}
@test "plugin_add refuses a plugin for another terminal and a conflict" {
  status=0
  output="$(plugin_add kitty-only 2>&1)" || status=$?
  [ "$status" -eq 1 ]; assert_contains "$output" "kitty-only works on: kitty"
  plugin_add demo >/dev/null
  status=0
  output="$(plugin_add clash 2>&1)" || status=$?
  [ "$status" -eq 1 ]; assert_contains "$output" "conflicts with demo"
}
@test "plugin_add enables requires_plugins first" {
  status=0
  output="$(plugin_add needs-demo 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(config_list plugins | tr '\n' ' ')" = "demo needs-demo " ]
}
@test "plugin_add of an unknown plugin fails clearly" {
  status=0
  output="$(plugin_add nope 2>&1)" || status=$?
  [ "$status" -eq 1 ]; assert_contains "$output" "no plugin named nope"
}
@test "plugin_add fails and does not record the plugin when brew install fails" {
  export FAKE_BREW_FAIL=1
  status=0
  output="$(plugin_add demo 2>&1)" || status=$?
  [ "$status" -eq 1 ]
  assert_contains "$output" "Homebrew install failed"
  [ -z "$(config_list plugins)" ]
}
@test "plugin_add fails and does not record a plugin whose install hook fails" {
  status=0
  output="$(plugin_add broken 2>&1)" || status=$?
  [ "$status" -eq 1 ]
  assert_contains "$output" "broken install"
  [ -z "$(config_list plugins)" ]
}
@test "plugin_remove runs the hook, unlinks, keeps copies, drops the record" {
  plugin_add demo >/dev/null
  status=0
  output="$(plugin_remove demo 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  grep -q "demo uninstall" "$NEKOSHELL_CACHE/hooks.log"
  [ ! -e "$HOME/.config/demo/conf" ]; [ -f "$HOME/.config/demo/mine.conf" ]
  ! plugin_enabled demo
  ! grep -q zsh-example "$NEKOSHELL_CONFIG/antidote.txt"
  assert_not_contains "$output" "brew uninstall"
}
@test "plugin_remove purge uninstalls formulas no other enabled plugin needs" {
  export FAKE_BREW_INSTALLED="eza"
  plugin_add demo >/dev/null
  status=0
  output="$(plugin_remove demo purge 2>&1)" || status=$?
  assert_contains "$output" "brew uninstall eza"
}
@test "plugin_remove on a never-enabled plugin is a no-op, even with purge" {
  export FAKE_BREW_INSTALLED="eza"
  status=0
  output="$(plugin_remove demo purge 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "not enabled"
  assert_not_contains "$output" "brew uninstall"
  [ ! -f "$NEKOSHELL_CACHE/hooks.log" ] || ! grep -q "demo uninstall" "$NEKOSHELL_CACHE/hooks.log"
}
@test "plugin_remove refuses while a dependant is enabled" {
  plugin_add needs-demo >/dev/null
  status=0
  output="$(plugin_remove demo 2>&1)" || status=$?
  [ "$status" -eq 1 ]; assert_contains "$output" "needs-demo needs demo"
}
@test "plugin_providing_cmd finds the owner" {
  [ "$(plugin_providing_cmd demo)" = "demo" ]
  [ -z "$(plugin_providing_cmd nothing)" ]
}
@test "plugin_run_hook on a missing hook returns 0" {
  plugin_run_hook clash install
}
@test "copy_guard leaves an existing config alone and says so" {
  mkdir -p "$HOME/.config/guarded"
  printf 'mine\n' > "$HOME/.config/guarded/mine"
  status=0
  output="$(plugin_add guarded 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.config/guarded/mine")" = "mine" ]
  assert_contains "$output" "guarded: .config/guarded/mine exists; left your config alone"
  assert_contains "$output" "plugins/guarded/files/copy"
  plugin_enabled guarded
}
@test "copy_guard with no guard path present copies the plugin's file" {
  status=0
  output="$(plugin_add guarded 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.config/guarded/mine")" = "theirs" ]
  assert_not_contains "$output" "left your config alone"
}
@test "plugin_add survives a doctor hook that ends on a guarded, legitimately-false check" {
  status=0
  output="$(plugin_add flaky-doctor 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(config_list plugins)" = "flaky-doctor" ]
  assert_contains "$output" "ok   flaky"
}

# A dry run used to record the plugin as enabled without installing it: the
# brew, link and copy steps were gated, the two writes that follow were not.
@test "a dry-run plugin add reports what it would do and records nothing" {
  local st=0 out=""
  out="$(NEKOSHELL_DRY_RUN=1 "$REPO_ROOT/bin/nekoshell" plugin add demo 2>&1)" || st=$?
  [ "$st" -eq 0 ]
  assert_contains "$out" "would enable demo"
  [ "$(config_list plugins | tr -d '\n')" = "" ]
  [ ! -e "$NEKOSHELL_CONFIG/antidote.txt" ]
  [ ! -e "$HOME/.config/demo/conf" ]
}
@test "a dry-run plugin remove reports what it would do and records nothing" {
  plugin_add demo >/dev/null 2>&1
  local st=0 out=""
  out="$(NEKOSHELL_DRY_RUN=1 "$REPO_ROOT/bin/nekoshell" plugin remove demo 2>&1)" || st=$?
  [ "$st" -eq 0 ]
  assert_contains "$out" "would remove demo"
  [ "$(config_list plugins | tr -d '\n')" = "demo" ]
}
