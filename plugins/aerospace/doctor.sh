#!/usr/bin/env bash
# aerospace doctor: a note, never a failure.
#
# AeroSpace needs the Accessibility permission, which is a dialog a person has
# to answer — no install can finish that on its own. A Mac where the cask is
# there but the permission has not been granted, or where the user decided
# against it, is not a broken nekoshell, so this row never turns the doctor
# red. `list-workspaces` is the liveness probe: a running, permitted AeroSpace
# answers it, a launched-but-blocked one does not.

if command -v aerospace >/dev/null 2>&1 && aerospace list-workspaces --all >/dev/null 2>&1; then
  report ok "aerospace" "$(command -v aerospace)"
elif command -v aerospace >/dev/null 2>&1; then
  report warn "aerospace" "installed but not answering; grant Accessibility in System Settings"
else
  report warn "aerospace" "not installed (nekoshell plugin add aerospace)"
fi

true
