# Environment shared by every nekoshell shell.
# nvim first, vim as the fallback every Mac already has. An EDITOR you set
# yourself wins over both, so neither line overrides your own choice.
(( $+commands[nvim] )) && export EDITOR="${EDITOR:-nvim}"
export EDITOR="${EDITOR:-vim}"
# Colours (BAT_THEME, FZF_DEFAULT_OPTS) live in theme.zsh, rendered by
# `nekoshell theme <flavour>` from core/theme/palettes.json. The zshrc
# sources it itself, right after this file, so it is not sourced again here.
# Without bat installed this pager turns every man page into an error.
(( $+commands[bat] )) && export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export EZA_COLORS="da=38;5;245:di=1;34:ex=1;32:ln=36:ur=33:uw=31:ux=32:gr=33:gw=31:gx=32:tr=33:tw=31:tx=32"
export LESS="-R"
