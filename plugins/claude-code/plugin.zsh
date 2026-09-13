# claude with the nekoshell banner in front of an interactive session. Any
# use that is not one (a prompt on the command line, a subcommand, a flag
# that answers and exits, no tty) runs the real binary untouched, so scripts
# and pipes never see the banner. Guarded: without claude on PATH the shell
# gets no function and pays one lookup.
if (( $+commands[claude] )); then
  claude() {
    local a
    if [[ -t 1 ]]; then
      for a in "$@"; do
        case "$a" in
          -p|--print|-v|--version|-h|--help|mcp|config|plugin|update|doctor|install|auth|setup-token)
            command claude "$@"
            return $?
            ;;
        esac
      done
      nekoshell-ai-welcome claude-code
    fi
    command claude "$@"
  }
fi
true
