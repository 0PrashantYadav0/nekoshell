# Aliases. eza/bat replace ls/cat only when installed.
if (( $+commands[eza] )); then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza --icons --group-directories-first -l --git'
  alias la='eza --icons --group-directories-first -la --git'
  alias lt='eza --icons --tree --level=2'
fi
(( $+commands[bat] )) && alias cat='bat --paging=never'
(( $+commands[lazygit] )) && alias lg='lazygit'
(( $+commands[btop] )) && alias top='btop'
if (( $+commands[nvim] )); then
  alias vim='nvim'
  alias vi='nvim'
fi
# One session called main: `t` attaches to it when it is there and starts it
# when it is not, so there is never a second one to pick between.
(( $+commands[tmux] )) && alias t='tmux new-session -A -s main'
alias greet='nekoshell-greet'
alias music='nekoshell-music'
alias doctor='nekoshell-doctor'
alias g='git'
alias ..='cd ..'
alias ...='cd ../..'
