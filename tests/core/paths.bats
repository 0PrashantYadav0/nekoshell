#!/usr/bin/env bats
load ../helpers

setup() { setup_tmp_home; }
teardown() { teardown_tmp_home; }

@test "paths derive from HOME" {
  run bash -c "source '$REPO_ROOT/core/lib/paths.sh'; echo \"\$NEKOSHELL_CONFIG|\$NEKOSHELL_CACHE|\$NEKOSHELL_BACKUP_ROOT\""
  [ "$output" = "$HOME/.config/nekoshell|$HOME/.cache/nekoshell|$HOME/.local/share/nekoshell/backup" ]
}

@test "nekoshell_root_from resolves the repo root from a bin path" {
  run bash -c "source '$REPO_ROOT/core/lib/paths.sh'; nekoshell_root_from '$REPO_ROOT/bin/anything'"
  [ "$output" = "$REPO_ROOT" ]
}
