#!/usr/bin/env bash
# pure doctor: the prompt function Homebrew installed, and the colours file
# the flavour switch renders.

_pure_fn=""
for _p in "${HOMEBREW_PREFIX:-/opt/homebrew}" /opt/homebrew /usr/local; do
  if [[ -r "$_p/share/zsh/site-functions/prompt_pure_setup" ]]; then
    _pure_fn="$_p/share/zsh/site-functions/prompt_pure_setup"
    break
  fi
done
if [[ -n "$_pure_fn" ]]; then
  report ok "pure prompt" "$_pure_fn"
else
  report fail "pure prompt" "prompt_pure_setup missing (nekoshell plugin add pure)"
fi

if [[ -r "$NEKOSHELL_CONFIG/pure-colors.zsh" ]] && grep -q "$(printf '%s' "${FLAVOR:0:1}" | tr '[:lower:]' '[:upper:]')${FLAVOR:1}" "$NEKOSHELL_CONFIG/pure-colors.zsh"; then
  report ok "pure colours" "$FLAVOR"
else
  report fail "pure colours" "not rendered for $FLAVOR (run: nekoshell theme $FLAVOR)"
fi

true
