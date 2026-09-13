#!/usr/bin/env bash
# version: print nekoshell's version
usage_version() {
  cat <<'EOF'
usage: nekoshell version
EOF
}
cmd_version() { printf 'nekoshell %s\n' "$(cat "$NEKOSHELL_ROOT/VERSION")"; }
