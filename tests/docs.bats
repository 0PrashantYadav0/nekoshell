#!/usr/bin/env bats
load helpers

@test "every documented command exists" {
  for f in README.md AGENTS.md docs/INSTALL.md docs/REMOTE.md skills/nekoshell/SKILL.md; do
    [ -f "$REPO_ROOT/$f" ]
  done
  grep -q -- '--yes' "$REPO_ROOT/AGENTS.md"
  grep -q 'nekoshell-doctor' "$REPO_ROOT/AGENTS.md"
  grep -q 'spotify_player authenticate' "$REPO_ROOT/AGENTS.md"
  grep -q -- '--iterm-prefs' "$REPO_ROOT/AGENTS.md"
  grep -q 'backup' "$REPO_ROOT/AGENTS.md"
  grep -q 'nekoshell-theme' "$REPO_ROOT/AGENTS.md"
  grep -q 'nekoshell-theme' "$REPO_ROOT/README.md"
  grep -q 'NEKOSHELL_GREET_SSH' "$REPO_ROOT/docs/REMOTE.md"
  grep -q -- '--skip-spotify' "$REPO_ROOT/docs/REMOTE.md"
  grep -q '^name: nekoshell' "$REPO_ROOT/skills/nekoshell/SKILL.md"
  grep -q '^description:' "$REPO_ROOT/skills/nekoshell/SKILL.md"
}

@test "changelog has a v0.1.0 entry" {
  grep -q '0.1.0' "$REPO_ROOT/CHANGELOG.md"
}
