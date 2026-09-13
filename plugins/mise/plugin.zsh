# mise: the shell hook that puts the right tool versions on PATH as you
# change directory, and completions cached to a file the way the gh plugin
# does it. Guarded, so a shell without mise pays one lookup.
if (( $+commands[mise] )); then
  eval "$(mise activate zsh)"
  _nk_mise_comp="$HOME/.cache/nekoshell/mise-completion.zsh"
  if [[ ! -s "$_nk_mise_comp" || "$commands[mise]" -nt "$_nk_mise_comp" ]]; then
    mkdir -p "$HOME/.cache/nekoshell"
    mise completion zsh >| "$_nk_mise_comp" 2>/dev/null
  fi
  [[ -s "$_nk_mise_comp" ]] && source "$_nk_mise_comp"
  unset _nk_mise_comp
fi
true
