#!/usr/bin/env bash
# ai doctor: the banner templates and the colours file.

if [[ -r "$NEKOSHELL_CONFIG/ai/welcome.txt" ]]; then
  report ok "ai templates" "$NEKOSHELL_CONFIG/ai/welcome.txt"
else
  report fail "ai templates" "welcome.txt missing (nekoshell plugin add ai)"
fi

if [[ -r "$NEKOSHELL_CONFIG/ai/colors.sh" ]] && grep -q "$(printf '%s' "${FLAVOR:0:1}" | tr '[:lower:]' '[:upper:]')${FLAVOR:1}" "$NEKOSHELL_CONFIG/ai/colors.sh"; then
  report ok "ai colours" "$FLAVOR"
else
  report fail "ai colours" "not rendered for $FLAVOR (run: nekoshell theme $FLAVOR)"
fi

true
