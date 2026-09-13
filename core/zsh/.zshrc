# nekoshell zshrc. Managed by https://github.com/0PrashantYadav0/nekoshell
# Your own additions go in ~/.config/nekoshell/zsh/local.zsh (never overwritten).

NEKOSHELL_ROOT="${${(%):-%x}:A:h:h:h}"
export NEKOSHELL_ROOT
NEKOSHELL_CONFIG="$HOME/.config/nekoshell"
NEKOSHELL_PLUGINS_DIR="${NEKOSHELL_PLUGINS_DIR:-$NEKOSHELL_ROOT/plugins}"
typeset -U path
path=("$NEKOSHELL_ROOT/bin" "$HOME/.local/bin" $path)

# Enabled plugins and the theme setting, read from nekoshell.toml with no
# external process.
_nk_plugins=()
_nk_theme=""
if [[ -r "$NEKOSHELL_CONFIG/nekoshell.toml" ]]; then
  # An anonymous function so the `[[:space:]]#` closures get extended_glob
  # without turning the option on in the user's shell. Any spacing around the
  # `=` matches, so a toml a person edited by hand still parses.
  () {
    emulate -L zsh -o extended_glob
    local -a _nk_lines
    _nk_lines=(${(f)"$(<"$NEKOSHELL_CONFIG/nekoshell.toml")"})
    _nk_line=${${(M)_nk_lines:#plugins[[:space:]]#=*}[1]}
    _nk_theme_line=${${(M)_nk_lines:#theme[[:space:]]#=*}[1]}
  }
  _nk_plugins=(${(s:,:)${${_nk_line#*\[}%\]*}//[\" ]/})
  # Strip "theme = " and any quotes/spaces, leaving just the value, so this
  # does not depend on the exact spacing toml_set happens to write.
  _nk_theme=${${_nk_theme_line#*=}//[\" ]/}
fi

# theme = "auto" is resolved by `nekoshell theme --resolve`, which only
# writes when the resolved flavour actually changed. Run in the background so
# the prompt is not delayed; the next shell picks up the change.
if [[ -o interactive ]] && [[ "$_nk_theme" == "auto" ]]; then
  (nekoshell theme --resolve >/dev/null 2>&1 &)
fi

[[ -r "$NEKOSHELL_CONFIG/zsh/env.zsh" ]] && source "$NEKOSHELL_CONFIG/zsh/env.zsh"
[[ -r "$NEKOSHELL_CONFIG/theme.zsh" ]] && source "$NEKOSHELL_CONFIG/theme.zsh"

# The running terminal's own zsh hook, terminals/<id>/zsh.zsh, when the
# adapter ships one (Ghostty's turns its quick terminal into the music
# panel). Detected from the environment the same way core/lib/terminal.sh
# does it, with no process started. This runs early on purpose: a hook that
# replaces the shell should not wait for the plugins to load first.
_nk_term=""
if [[ -n "${KITTY_WINDOW_ID:-}" || "${TERM:-}" == "xterm-kitty" ]]; then _nk_term=kitty
elif [[ -n "${GHOSTTY_RESOURCES_DIR:-}" || "${TERM_PROGRAM:-}" == "ghostty" ]]; then _nk_term=ghostty
else
  case "${TERM_PROGRAM:-}" in
    iTerm.app) _nk_term=iterm2 ;;
    Apple_Terminal) _nk_term=terminal-app ;;
    WarpTerminal) _nk_term=warp ;;
    WezTerm) _nk_term=wezterm ;;
  esac
fi
NEKOSHELL_TERMINALS_DIR="${NEKOSHELL_TERMINALS_DIR:-$NEKOSHELL_ROOT/terminals}"
if [[ -n "$_nk_term" && -r "$NEKOSHELL_TERMINALS_DIR/$_nk_term/zsh.zsh" ]]; then
  source "$NEKOSHELL_TERMINALS_DIR/$_nk_term/zsh.zsh"
fi

HISTFILE="$HOME/.zsh_history"; HISTSIZE=50000; SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS SHARE_HISTORY HIST_IGNORE_SPACE
autoload -Uz compinit && compinit -C
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# antidote: the generated bundle (core + enabled plugins).
if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then _nk_prefixes=("$HOMEBREW_PREFIX"); else _nk_prefixes=(/opt/homebrew /usr/local); fi
for _nk_prefix in "${_nk_prefixes[@]}"; do
  if [[ -r "$_nk_prefix/opt/antidote/share/antidote/antidote.zsh" && -r "$NEKOSHELL_CONFIG/antidote.txt" ]]; then
    source "$_nk_prefix/opt/antidote/share/antidote/antidote.zsh"
    antidote load "$NEKOSHELL_CONFIG/antidote.txt"
    break
  fi
done
unset _nk_prefix _nk_prefixes

[[ -r "$NEKOSHELL_CONFIG/zsh/aliases.zsh" ]] && source "$NEKOSHELL_CONFIG/zsh/aliases.zsh"

for _p in $_nk_plugins; do
  [[ -d "$NEKOSHELL_PLUGINS_DIR/$_p/bin" ]] && path=("$NEKOSHELL_PLUGINS_DIR/$_p/bin" $path)
  [[ -r "$NEKOSHELL_PLUGINS_DIR/$_p/plugin.zsh" ]] && source "$NEKOSHELL_PLUGINS_DIR/$_p/plugin.zsh"
done

(( $+commands[starship] )) && eval "$(starship init zsh)"

# iTerm2's own zsh hooks, which `nekoshell terminal apply` downloads. They are
# what reports the working directory and the last command's status to the
# status bar, so without this the bar's directory and git components stay
# blank. Only inside iTerm2: elsewhere the escapes they emit are noise.
[[ "${TERM_PROGRAM:-}" == "iTerm.app" && -r "$HOME/.iterm2_shell_integration.zsh" ]] && source "$HOME/.iterm2_shell_integration.zsh"

for _p in $_nk_plugins; do
  [[ -r "$NEKOSHELL_PLUGINS_DIR/$_p/late.zsh" ]] && source "$NEKOSHELL_PLUGINS_DIR/$_p/late.zsh"
done
unset _p _nk_line _nk_theme_line _nk_theme _nk_term

[[ -r "$NEKOSHELL_CONFIG/zsh/local.zsh" ]] && source "$NEKOSHELL_CONFIG/zsh/local.zsh"
