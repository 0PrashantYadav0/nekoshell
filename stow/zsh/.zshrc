# nekoshell zshrc. Managed by https://github.com/0PrashantYadav0/nekoshell
# Put your own additions in ~/.config/nekoshell/zsh/local.zsh (never overwritten).

# Locate the checkout from this file's real path: stow/zsh/.zshrc -> repo root.
NEKOSHELL_ROOT="${${(%):-%x}:A:h:h:h}"
export NEKOSHELL_ROOT
typeset -U path
export PATH="$NEKOSHELL_ROOT/bin:$HOME/.local/bin:$PATH"

NEKOSHELL_CONFIG="$HOME/.config/nekoshell"

[[ -r "$NEKOSHELL_CONFIG/zsh/env.zsh" ]] && source "$NEKOSHELL_CONFIG/zsh/env.zsh"
[[ -r "$NEKOSHELL_CONFIG/zsh/aliases.zsh" ]] && source "$NEKOSHELL_CONFIG/zsh/aliases.zsh"
[[ -r "$NEKOSHELL_CONFIG/zsh/local.zsh" ]] && source "$NEKOSHELL_CONFIG/zsh/local.zsh"

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS SHARE_HISTORY HIST_IGNORE_SPACE

# Completion
autoload -Uz compinit && compinit -C
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# Plugins via antidote. Homebrew's prefix is /opt/homebrew on Apple silicon and
# /usr/local on Intel; an explicit HOMEBREW_PREFIX wins and is the only one tried.
if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
  _nk_prefixes=("$HOMEBREW_PREFIX")
else
  _nk_prefixes=(/opt/homebrew /usr/local)
fi
for _nk_prefix in "${_nk_prefixes[@]}"; do
  if [[ -r "$_nk_prefix/opt/antidote/share/antidote/antidote.zsh" ]]; then
    source "$_nk_prefix/opt/antidote/share/antidote/antidote.zsh"
    antidote load "$NEKOSHELL_CONFIG/zsh/plugins.txt"
    break
  fi
done
unset _nk_prefix _nk_prefixes

# Tools
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
(( $+commands[fzf] )) && source <(fzf --zsh)
# Previews for the fzf bindings, after fzf has installed them.
[[ -r "$NEKOSHELL_CONFIG/zsh/fzf.zsh" ]] && source "$NEKOSHELL_CONFIG/zsh/fzf.zsh"
# atuin after fzf, so Ctrl-R lands on atuin's searchable history. The up arrow
# is left on plain zsh history, which is what it looks like it should do.
(( $+commands[atuin] )) && eval "$(atuin init zsh --disable-up-arrow)"
(( $+commands[starship] )) && eval "$(starship init zsh)"

# iTerm2 shell integration. It tells iTerm2 the working directory and the state
# of the last command, which is what the status bar's first two components read.
# install.sh downloads it; without it those components stay blank.
[[ -r "$HOME/.iterm2_shell_integration.zsh" ]] && source "$HOME/.iterm2_shell_integration.zsh"

# Greeting: only for interactive shells that own a terminal.
if [[ -o interactive ]] && (( $+commands[nekoshell-greet] )); then
  nekoshell-greet
fi
