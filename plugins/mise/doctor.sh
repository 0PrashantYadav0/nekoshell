#!/usr/bin/env bash
# mise doctor: the binary and the global config.

if command -v mise >/dev/null 2>&1; then
  report ok "tool: mise" "$(command -v mise)"
else
  report fail "tool: mise" "missing (nekoshell plugin add mise)"
fi

if [[ -f "$HOME/.config/mise/config.toml" ]]; then
  report ok "mise config" "$HOME/.config/mise/config.toml"
else
  report warn "mise config" "no ~/.config/mise/config.toml (nekoshell plugin add mise copies one)"
fi

true
