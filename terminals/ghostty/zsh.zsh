# nekoshell's Ghostty hook, sourced by the core .zshrc when the shell runs in
# Ghostty. Ghostty's quick terminal starts a plain shell, with no way to give
# it a command from the config, so this is what turns it into the music panel:
# the first interactive shell inside it becomes `nekoshell music --here`.
# `ghostty_quick_terminal = "shell"` in nekoshell.toml keeps it a plain shell.
# zsh, not bash: no bashisms here.
[[ -o interactive ]] || return 0
if [[ "${GHOSTTY_QUICK_TERMINAL:-}" == 1 && -z "${NEKOSHELL_PANEL:-}" ]]; then
  # The toml key, read without an external process; NEKOSHELL_GHOSTTY_QUICK
  # set in the environment wins over it.
  if [[ -z "${NEKOSHELL_GHOSTTY_QUICK:-}" && -r "${NEKOSHELL_CONFIG:-$HOME/.config/nekoshell}/nekoshell.toml" ]]; then
    () {
      emulate -L zsh -o extended_glob
      local -a _nk_lines
      _nk_lines=(${(f)"$(<"${NEKOSHELL_CONFIG:-$HOME/.config/nekoshell}/nekoshell.toml")"})
      NEKOSHELL_GHOSTTY_QUICK=${${${(M)_nk_lines:#ghostty_quick_terminal[[:space:]]#=*}[1]#*=}//[\" ]/}
    }
  fi
  if [[ "${NEKOSHELL_GHOSTTY_QUICK:-music}" == music ]] && (( $+commands[nekoshell] )); then
    # NEKOSHELL_PANEL tells the greet plugin to stay quiet, and a shell the
    # player itself opens inherits it, so it never becomes another player.
    export NEKOSHELL_PANEL=1
    exec nekoshell music --here
  fi
fi
true
