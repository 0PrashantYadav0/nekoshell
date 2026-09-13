# gh: completions cached to a file (gh takes a few tens of milliseconds to
# print them), regenerated when the binary is newer than the cache; delta as
# the pager for diffs when the modern-cli plugin put it on PATH. Guarded, so
# a shell without gh pays one lookup.
if (( $+commands[gh] )); then
  _nk_gh_comp="$HOME/.cache/nekoshell/gh-completion.zsh"
  if [[ ! -s "$_nk_gh_comp" || "$commands[gh]" -nt "$_nk_gh_comp" ]]; then
    mkdir -p "$HOME/.cache/nekoshell"
    gh completion -s zsh >| "$_nk_gh_comp" 2>/dev/null
  fi
  [[ -s "$_nk_gh_comp" ]] && source "$_nk_gh_comp"
  unset _nk_gh_comp
  (( $+commands[delta] )) && export GH_PAGER="delta"
fi
true
