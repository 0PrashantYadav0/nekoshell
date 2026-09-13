#!/usr/bin/env bash
# p10k doctor: the theme Homebrew installed, the user's config, and the
# colours file the flavour switch renders.

_p10k_theme=""
for _p in "${HOMEBREW_PREFIX:-/opt/homebrew}" /opt/homebrew /usr/local; do
  if [[ -r "$_p/share/powerlevel10k/powerlevel10k.zsh-theme" ]]; then
    _p10k_theme="$_p/share/powerlevel10k/powerlevel10k.zsh-theme"
    break
  fi
done
if [[ -n "$_p10k_theme" ]]; then
  report ok "p10k theme" "$_p10k_theme"
else
  report fail "p10k theme" "powerlevel10k missing (nekoshell plugin add p10k)"
fi

if [[ -r "$HOME/.p10k.zsh" ]]; then
  report ok "p10k config" "$HOME/.p10k.zsh"
else
  report warn "p10k config" "no ~/.p10k.zsh; run: p10k configure (or nekoshell plugin add p10k to copy ours)"
fi

if [[ -r "$NEKOSHELL_CONFIG/p10k-colors.zsh" ]] && grep -q "$(printf '%s' "${FLAVOR:0:1}" | tr '[:lower:]' '[:upper:]')${FLAVOR:1}" "$NEKOSHELL_CONFIG/p10k-colors.zsh"; then
  report ok "p10k colours" "$FLAVOR"
else
  report fail "p10k colours" "not rendered for $FLAVOR (run: nekoshell theme $FLAVOR)"
fi

true
