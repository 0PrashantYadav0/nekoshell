# atuin takes over Ctrl-R. `fzf --zsh` binds Ctrl-R too, so whichever runs last
# wins — and the order two plugin.zsh files load in is the order the plugins
# happened to be added in, which is not something to bet a key binding on. This
# is late.zsh, which the zshrc sources after every plugin.zsh, so atuin's
# binding is the one that survives however the two were enabled.
#
# --disable-up-arrow leaves the up arrow walking this session's history, which
# is what it is for; atuin answers Ctrl-R.
if (( $+commands[atuin] )); then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

true
