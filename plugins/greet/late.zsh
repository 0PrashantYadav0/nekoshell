# The greeting goes last, after the prompt is set up, so nothing it prints is
# drawn over. It is skipped whenever there is no one to read it: a shell that
# is not interactive, or one whose stdout is not a terminal (a script, a
# command substitution), and over SSH unless you asked for it.
#
# nekoshell-greet makes the same checks itself — it has to, because a login
# shell is not the only thing that runs it — but they are cheap here, and this
# way the common non-interactive case never starts a process at all.
if (( $+commands[nekoshell-greet] )); then
  [[ -o interactive && -t 1 ]] && {
    [[ -z "${SSH_CONNECTION:-}" || "${NEKOSHELL_GREET_SSH:-}" == 1 ]] && nekoshell-greet
  }
fi

true
