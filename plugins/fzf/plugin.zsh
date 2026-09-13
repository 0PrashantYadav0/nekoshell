# fzf's own key bindings and completion first, then the previews that decide
# what those bindings show. Guarded: with no fzf installed this plugin costs one
# command lookup and changes nothing.
if (( $+commands[fzf] )); then
  source <(fzf --zsh)

  # $0 inside a sourced file is the file itself, so the previews are found
  # next to this one however the plugin directory is reached. The fallback is
  # for a zsh with FUNCTION_ARGZERO turned off, where $0 is the shell's name.
  _nk_fzf_dir="${0:A:h}"
  [[ -r "$_nk_fzf_dir/fzf.zsh" ]] || _nk_fzf_dir="${NEKOSHELL_PLUGINS_DIR:-$NEKOSHELL_ROOT/plugins}/fzf"
  [[ -r "$_nk_fzf_dir/fzf.zsh" ]] && source "$_nk_fzf_dir/fzf.zsh"
  unset _nk_fzf_dir
fi

true
