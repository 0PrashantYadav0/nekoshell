# opencode with the nekoshell banner in front of an interactive session.
# Non-interactive uses (run, serve, auth, upgrade, models, a flag that
# answers and exits, no tty) run the real binary untouched. Guarded: without
# opencode on PATH the shell gets no function and pays one lookup.
if (( $+commands[opencode] )); then
  opencode() {
    local a
    if [[ -t 1 ]]; then
      for a in "$@"; do
        case "$a" in
          run|serve|auth|upgrade|models|-v|--version|-h|--help)
            command opencode "$@"
            return $?
            ;;
        esac
      done
      nekoshell-ai-welcome opencode
    fi
    command opencode "$@"
  }
fi
true
