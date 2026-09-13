# Aliases for the modern replacements. Each one is guarded, so a plugin that is
# enabled on a machine where Homebrew has not caught up yet costs one lookup and
# changes nothing.
if (( $+commands[eza] )); then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza --icons --group-directories-first -l --git'
  alias la='eza --icons --group-directories-first -la --git'
  alias lt='eza --icons --tree --level=2'
fi

if (( $+commands[bat] )); then
  alias cat='bat --paging=never'
fi

# zoxide replaces cd with one that learns. `init zsh` is the only thing here
# that runs a process, and only when zoxide is actually installed.
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

true
