# yazi's documented shell wrapper: y opens yazi and, on quit, changes to the
# directory it was in. Guarded, so a shell without yazi pays one lookup.
if (( $+commands[yazi] )); then
  y() {
    local tmp cwd
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
      builtin cd -- "$cwd" || return
    fi
    rm -f -- "$tmp"
  }
fi
true
