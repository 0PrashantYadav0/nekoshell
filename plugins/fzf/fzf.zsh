# fzf previews. Sourced from .zshrc after `fzf --zsh` installs the key bindings,
# so these only change what the bindings show, never the bindings themselves.
# Colours come from FZF_DEFAULT_OPTS in theme.zsh, which the theme renders.

# Ctrl-T: files. bat's line range keeps the preview cheap on a huge file.
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}' --preview-window=right:60%"
# Alt-C: directories, two levels of tree.
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons --color=always {}' --preview-window=right:60%"
# Ctrl-R: history. atuin takes this binding over when it is installed, so this
# preview only ever shows on a machine without atuin. The preview is the command
# itself, wrapped, because a long one-liner is otherwise cut off at the width of
# the list.
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window=down:3:wrap"

# fd walks faster than find and honours .gitignore. Without it, fzf's own
# default walk stands: setting this to an fd that is not there lists nothing.
if (( $+commands[fd] )); then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
fi

# fzf-tab reads these when a completion opens, so they can be set after the
# plugin has loaded.
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --icons --color=always -1 $realpath'
zstyle ':fzf-tab:*' use-fzf-default-opts yes
