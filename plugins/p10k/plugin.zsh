# Powerlevel10k in place of Starship. NEKOSHELL_PROMPT tells the core zshrc
# not to start Starship; the theme is Homebrew's, found under whichever prefix
# this Mac uses; the colours come from the file the theme hook renders; the
# config is the user's ~/.p10k.zsh, sourced last so it wins.
export NEKOSHELL_PROMPT=p10k
for _nk_p in "${HOMEBREW_PREFIX:-/opt/homebrew}" /opt/homebrew /usr/local; do
  if [[ -r "$_nk_p/share/powerlevel10k/powerlevel10k.zsh-theme" ]]; then
    source "$_nk_p/share/powerlevel10k/powerlevel10k.zsh-theme"
    break
  fi
done
unset _nk_p
[[ -r "$NEKOSHELL_CONFIG/p10k-colors.zsh" ]] && source "$NEKOSHELL_CONFIG/p10k-colors.zsh"
[[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
true
