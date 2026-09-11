# Environment shared by every nekoshell shell.
export EDITOR="${EDITOR:-vim}"
export BAT_THEME="Catppuccin Mocha"
# Without bat installed this pager turns every man page into an error.
(( $+commands[bat] )) && export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--color=selected-bg:#45475a --multi --height=40% --layout=reverse --border=rounded"
export EZA_COLORS="da=38;5;245:di=1;34:ex=1;32:ln=36:ur=33:uw=31:ux=32:gr=33:gw=31:gx=32:tr=33:tw=31:tx=32"
export LESS="-R"
