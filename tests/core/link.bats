#!/usr/bin/env bats
load ../helpers
setup() {
  setup_tmp_home
  export NEKOSHELL_ROOT="$REPO_ROOT"
  for l in paths log backup link; do source "$REPO_ROOT/core/lib/$l.sh"; done
  SRC="$HOME/src"; mkdir -p "$SRC/.config/app" "$SRC/.config/nested/deep"
  echo one > "$SRC/.zshrc"; echo two > "$SRC/.config/app/conf"; echo three > "$SRC/.config/nested/deep/f"
  DEST="$HOME/dest"; mkdir -p "$DEST"
  backup_begin
}
teardown() { teardown_tmp_home; }

@test "link_tree mirrors every file as an absolute symlink" {
  link_tree "$SRC" "$DEST"
  [ -L "$DEST/.zshrc" ]; [ "$(readlink "$DEST/.zshrc")" = "$SRC/.zshrc" ]
  [ -L "$DEST/.config/app/conf" ]; [ -L "$DEST/.config/nested/deep/f" ]
  [ "$(cat "$DEST/.config/nested/deep/f")" = "three" ]
}
@test "link_tree backs up a real file in the way and is idempotent" {
  echo mine > "$DEST/.zshrc"
  link_tree "$SRC" "$DEST"
  [ -L "$DEST/.zshrc" ]
  [ "$(find "$NEKOSHELL_BACKUP_ROOT" -name '.zshrc' -type f | wc -l | tr -d ' ')" -eq 1 ]
  link_tree "$SRC" "$DEST"
  [ "$(find "$NEKOSHELL_BACKUP_ROOT" -name '.zshrc' -type f | wc -l | tr -d ' ')" -eq 1 ]
}
@test "link_tree replaces a symlink that points elsewhere without backing it up" {
  ln -s /etc/hosts "$DEST/.zshrc"
  link_tree "$SRC" "$DEST"
  [ "$(readlink "$DEST/.zshrc")" = "$SRC/.zshrc" ]
  [ -z "$(find "$NEKOSHELL_BACKUP_ROOT" -name '.zshrc' 2>/dev/null)" ]
}
@test "unlink_tree removes only links that point into SRC" {
  link_tree "$SRC" "$DEST"
  ln -s /etc/hosts "$DEST/.config/other"
  unlink_tree "$SRC" "$DEST"
  [ ! -e "$DEST/.zshrc" ]; [ ! -e "$DEST/.config/app/conf" ]; [ -L "$DEST/.config/other" ]
}
@test "copy_once copies missing files and never overwrites" {
  echo mine > "$DEST/.zshrc"
  # Not `run`: log.sh (sourced above) defines its own run(), which shadows
  # bats' run() for the rest of this test process and would leave $output
  # empty. Plain command substitution captures stdout/stderr and exit status
  # instead.
  status=0
  output="$(copy_once "$SRC" "$DEST" 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(cat "$DEST/.zshrc")" = "mine" ]
  [ "$(cat "$DEST/.config/app/conf")" = "two" ]; [ ! -L "$DEST/.config/app/conf" ]
  assert_contains "$output" "kept .zshrc"
}
@test "link_tree and copy_once on a missing SRC are no-ops" {
  link_tree "$HOME/nope" "$DEST"; copy_once "$HOME/nope" "$DEST"
  [ -z "$(ls -A "$DEST")" ]
}
@test "link_tree in dry-run creates nothing, skips the backup, and reports what it would do" {
  echo mine > "$DEST/.zshrc"
  NEKOSHELL_DRY_RUN=1; export NEKOSHELL_DRY_RUN
  status=0
  output="$(link_tree "$SRC" "$DEST" 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "would link .zshrc"
  [ "$(cat "$DEST/.zshrc")" = "mine" ]
  [ ! -e "$DEST/.config/app/conf" ]
  [ -z "$(find "$NEKOSHELL_BACKUP_ROOT" -name '.zshrc' 2>/dev/null)" ]
}
@test "copy_once in dry-run creates nothing and reports what it would do" {
  NEKOSHELL_DRY_RUN=1; export NEKOSHELL_DRY_RUN
  status=0
  output="$(copy_once "$SRC" "$DEST" 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "would copy .zshrc"
  [ -z "$(ls -A "$DEST")" ]
}
@test "unlink_tree in dry-run leaves the links in place and reports what it would do" {
  link_tree "$SRC" "$DEST"
  NEKOSHELL_DRY_RUN=1; export NEKOSHELL_DRY_RUN
  status=0
  output="$(unlink_tree "$SRC" "$DEST" 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "would unlink .zshrc"
  [ -L "$DEST/.zshrc" ]; [ -L "$DEST/.config/app/conf" ]
}
