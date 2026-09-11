# nekoshell zshrc. Managed by https://github.com/0PrashantYadav0/nekoshell
# Put your own additions in ~/.config/nekoshell/zsh/local.zsh (never overwritten).

# Locate the checkout from this file's real path: stow/zsh/.zshrc -> repo root.
NEKOSHELL_ROOT="${${(%):-%x}:A:h:h:h}"
export NEKOSHELL_ROOT
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

# Plugins via antidote (Homebrew)
if [[ -r "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/antidote/share/antidote/antidote.zsh" ]]; then
  source "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/antidote/share/antidote/antidote.zsh"
  antidote load "$NEKOSHELL_CONFIG/zsh/plugins.txt"
fi

# Tools
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
(( $+commands[fzf] )) && source <(fzf --zsh)
(( $+commands[starship] )) && eval "$(starship init zsh)"

# Greeting: only for interactive shells that own a terminal.
if [[ -o interactive ]] && (( $+commands[nekoshell-greet] )); then
  nekoshell-greet
fi
