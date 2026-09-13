#!/usr/bin/env bash
# pokemon doctor: the sprite pack, asked to draw something.

# Asked to draw something, not just to exist: a checkout whose python is gone
# or whose sprites never arrived answers `command -v` and nothing else.
if command -v pokemon-colorscripts >/dev/null 2>&1 && pokemon-colorscripts -r >/dev/null 2>&1; then
  report ok "pokemon-colorscripts" "$(command -v pokemon-colorscripts)"
else
  report fail "pokemon-colorscripts" "missing or broken (nekoshell plugin add pokemon)"
fi

true
