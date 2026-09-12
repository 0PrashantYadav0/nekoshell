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

@test "root fallback is not fooled by a rootless key and reads the real root key" {
  mkdir -p "$HOME/.config/nekoshell"
  cat > "$HOME/.config/nekoshell/nekoshell.toml" <<'EOF'
rootless = true
root = "/some/root"
EOF
  run bash -c "unset NEKOSHELL_ROOT; source '$REPO_ROOT/core/lib/paths.sh'; echo \"\$NEKOSHELL_ROOT\""
  [ "$output" = "/some/root" ]
}

@test "root fallback self-derives when only a rootless key is present" {
  mkdir -p "$HOME/.config/nekoshell"
  cat > "$HOME/.config/nekoshell/nekoshell.toml" <<'EOF'
rootless = true
EOF
  run bash -c "unset NEKOSHELL_ROOT; source '$REPO_ROOT/core/lib/paths.sh'; echo \"\$NEKOSHELL_ROOT\""
  [ "$output" = "$REPO_ROOT" ]
}
