# Neovim as the editor. Guarded: on a machine where the formula has not landed
# yet this costs one lookup and changes nothing, leaving whatever EDITOR the
# shell already had (core's env.zsh falls back to vim).
if (( $+commands[nvim] )); then
  alias vim=nvim
  alias vi=nvim
  export EDITOR=nvim
fi

true
