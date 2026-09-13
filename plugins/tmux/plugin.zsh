# One session called main, attached if it is already running and created if it
# is not, so `t` from any window lands in the same place.
if (( $+commands[tmux] )); then
  alias t='tmux new-session -A -s main'
fi

true
