# pure in place of Starship. NEKOSHELL_PROMPT tells the core zshrc not to
# start Starship; the prompt functions are Homebrew's (prompt_pure_setup and
# async under share/zsh/site-functions), found under whichever prefix this
# Mac uses; the colours come from the file the theme hook renders, and they
# are zstyles, so they have to be set before the prompt draws.
export NEKOSHELL_PROMPT=pure
for _nk_p in "${HOMEBREW_PREFIX:-/opt/homebrew}" /opt/homebrew /usr/local; do
  if [[ -r "$_nk_p/share/zsh/site-functions/prompt_pure_setup" ]]; then
    fpath=("$_nk_p/share/zsh/site-functions" $fpath)
    break
  fi
done
unset _nk_p
[[ -r "$NEKOSHELL_CONFIG/pure-colors.zsh" ]] && source "$NEKOSHELL_CONFIG/pure-colors.zsh"
autoload -Uz promptinit && promptinit && prompt pure
true
