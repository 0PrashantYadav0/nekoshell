# nekoshell zshrc. Managed by https://github.com/0PrashantYadav0/nekoshell
# Your own additions go in ~/.config/nekoshell/zsh/local.zsh (never overwritten).

NEKOSHELL_ROOT="${${(%):-%x}:A:h:h:h}"
export NEKOSHELL_ROOT
NEKOSHELL_CONFIG="$HOME/.config/nekoshell"
NEKOSHELL_PLUGINS_DIR="${NEKOSHELL_PLUGINS_DIR:-$NEKOSHELL_ROOT/plugins}"
typeset -U path
path=("$NEKOSHELL_ROOT/bin" "$HOME/.local/bin" $path)

# Enabled plugins and the theme setting, read from nekoshell.toml with no
# external process.
_nk_plugins=()
_nk_theme_line=""
if [[ -r "$NEKOSHELL_CONFIG/nekoshell.toml" ]]; then
  _nk_line=${${(M)${(f)"$(<"$NEKOSHELL_CONFIG/nekoshell.toml")"}:#plugins\ =*}[1]}
  _nk_plugins=(${(s:,:)${${_nk_line#*\[}%\]*}//[\" ]/})
  _nk_theme_line=${${(M)${(f)"$(<"$NEKOSHELL_CONFIG/nekoshell.toml")"}:#theme\ =*}[1]}
fi

# theme = "auto" is resolved by `nekoshell theme --resolve`, which only
# writes when the resolved flavour actually changed. Run in the background so
# the prompt is not delayed; the next shell picks up the change.
if [[ -o interactive ]] && [[ "$_nk_theme_line" == 'theme = "auto"' ]]; then
  (nekoshell theme --resolve >/dev/null 2>&1 &)
fi

[[ -r "$NEKOSHELL_CONFIG/zsh/env.zsh" ]] && source "$NEKOSHELL_CONFIG/zsh/env.zsh"
[[ -r "$NEKOSHELL_CONFIG/theme.zsh" ]] && source "$NEKOSHELL_CONFIG/theme.zsh"

HISTFILE="$HOME/.zsh_history"; HISTSIZE=50000; SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS SHARE_HISTORY HIST_IGNORE_SPACE
autoload -Uz compinit && compinit -C
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# antidote: the generated bundle (core + enabled plugins).
if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then _nk_prefixes=("$HOMEBREW_PREFIX"); else _nk_prefixes=(/opt/homebrew /usr/local); fi
for _nk_prefix in "${_nk_prefixes[@]}"; do
  if [[ -r "$_nk_prefix/opt/antidote/share/antidote/antidote.zsh" && -r "$NEKOSHELL_CONFIG/antidote.txt" ]]; then
    source "$_nk_prefix/opt/antidote/share/antidote/antidote.zsh"
    antidote load "$NEKOSHELL_CONFIG/antidote.txt"
    break
  fi
done
unset _nk_prefix _nk_prefixes

[[ -r "$NEKOSHELL_CONFIG/zsh/aliases.zsh" ]] && source "$NEKOSHELL_CONFIG/zsh/aliases.zsh"

for _p in $_nk_plugins; do
  [[ -d "$NEKOSHELL_PLUGINS_DIR/$_p/bin" ]] && path=("$NEKOSHELL_PLUGINS_DIR/$_p/bin" $path)
  [[ -r "$NEKOSHELL_PLUGINS_DIR/$_p/plugin.zsh" ]] && source "$NEKOSHELL_PLUGINS_DIR/$_p/plugin.zsh"
done

(( $+commands[starship] )) && eval "$(starship init zsh)"

for _p in $_nk_plugins; do
  [[ -r "$NEKOSHELL_PLUGINS_DIR/$_p/late.zsh" ]] && source "$NEKOSHELL_PLUGINS_DIR/$_p/late.zsh"
done
unset _p _nk_line _nk_theme_line

[[ -r "$NEKOSHELL_CONFIG/zsh/local.zsh" ]] && source "$NEKOSHELL_CONFIG/zsh/local.zsh"
