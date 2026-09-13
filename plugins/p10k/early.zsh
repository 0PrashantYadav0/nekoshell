# Powerlevel10k's instant prompt draws a cached prompt before the rest of the
# shell has loaded, and it has to be the first thing that runs. It also wants
# the top of the window to itself: with the greet plugin enabled the greeting
# is printed during startup, which instant prompt would warn about on every
# new shell, so it is switched off then and the prompt simply arrives after
# the greeting.
if (( ${_nk_plugins[(Ie)greet]} )); then
  typeset -g NEKOSHELL_P10K_INSTANT_PROMPT=off
elif [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
true
