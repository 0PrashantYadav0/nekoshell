#!/usr/bin/env bash
# tmux doctor: the binary, and the flavour file the config sources.

if command -v tmux >/dev/null 2>&1; then
  report ok "tool: tmux" "$(command -v tmux)"
else
  report fail "tool: tmux" "missing (nekoshell plugin add tmux)"
fi

# The theme hook writes this; a missing one means the hook never ran, which
# leaves tmux on catppuccin's own default rather than the chosen flavour.
if [[ -r "$HOME/.config/tmux/nekoshell-theme.conf" ]]; then
  report ok "tmux theme" "$(sed -n 's/.*@catppuccin_flavor "\(.*\)".*/\1/p' "$HOME/.config/tmux/nekoshell-theme.conf")"
else
  report warn "tmux theme" "run: nekoshell theme $FLAVOR"
fi

# TPM is what fetches the plugins the config names, including the status line.
if [[ -x "$HOME/.config/tmux/plugins/tpm/tpm" ]]; then
  report ok "tpm" "$HOME/.config/tmux/plugins/tpm"
else
  report warn "tpm" "missing (nekoshell plugin add tmux)"
fi

true
