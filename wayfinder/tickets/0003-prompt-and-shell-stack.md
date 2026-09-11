---
id: 0003
title: Decide the zsh prompt and plugin stack
type: wayfinder:grilling
status: closed
assignee: claude (2026-09-11)
blocked_by: []
---

## Question

Keep oh-my-zsh + Powerlevel10k, or move to Starship + antidote? Fact: p10k's instant prompt warns whenever `.zshrc` prints output during init, which a fastfetch greeting does. Recommendation: Starship (one TOML, cross-shell, Catppuccin preset) + antidote for zsh-autosuggestions, zsh-syntax-highlighting, fzf-tab. Migrate the user's existing aliases from the current 115-line `.zshrc`.

## Resolution

Decided by the user on 2026-09-11: **Starship** prompt (Catppuccin Mocha palette) and **antidote** for plugins (zsh-autosuggestions, zsh-syntax-highlighting, fzf-tab). oh-my-zsh and Powerlevel10k are retired; the installer backs up the current `.zshrc` and `.p10k.zsh` and migrates aliases from the 115-line `.zshrc`.
