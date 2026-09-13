#!/usr/bin/env bash
# Homebrew helpers. Every function is a no-op for what is already installed.
# Needs log.sh (run). Source this file; do not execute it.

brew_has() { brew list --formula "$1" >/dev/null 2>&1; }
brew_cask_has() { brew list --cask "$1" >/dev/null 2>&1; }

# brew_install FORMULA...: install the missing ones in one brew call.
brew_install() {
  local missing=() f
  for f in "$@"; do brew_has "$f" || missing+=("$f"); done
  [[ ${#missing[@]} -eq 0 ]] && return 0
  run brew install "${missing[@]}"
}

brew_cask_install() {
  local missing=() c
  for c in "$@"; do brew_cask_has "$c" || missing+=("$c"); done
  [[ ${#missing[@]} -eq 0 ]] && return 0
  run brew install --cask "${missing[@]}"
}

# brew_tap TAP: tap once.
brew_tap() {
  brew tap | grep -qx "$1" && return 0
  run brew tap "$1"
}
