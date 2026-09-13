#!/usr/bin/env bash
# tmux install: clone the tmux plugin manager, pinned.
#
# The commit is written down here rather than tracking master: TPM is what
# fetches every other tmux plugin, so an unpinned one makes two machines
# installed a month apart run different code.
#
# The path is written down too rather than left to TPM to guess. TPM picks
# ~/.config/tmux/plugins/ when the config lives there and ~/.tmux/plugins/
# when it does not; a clone in the other one is never read, and TPM fetches
# itself again with no pin at all. The shipped tmux.conf sets
# TMUX_PLUGIN_MANAGER_PATH to the same directory.

TPM_SHA="e261deb1b47614eed3400089ce7197dc68acc4eb"
TPM_DIR="$HOME/.config/tmux/plugins/tpm"

# Everything past the first clone is advisory. A machine that is offline, or
# whose ~/.config/tmux/plugins/tpm is a directory but not a checkout, still
# gets a working tmux: the shipped config guards every `run` of a plugin, and
# an older TPM manages plugins perfectly well. None of it is worth aborting
# `plugin add` over, so each step warns and the hook carries on.
if [[ ! -d "$TPM_DIR" ]]; then
  run mkdir -p "$(dirname "$TPM_DIR")"
  run git clone --quiet https://github.com/tmux-plugins/tpm.git "$TPM_DIR"
elif git -C "$TPM_DIR" cat-file -e "$TPM_SHA^{commit}" 2>/dev/null; then
  : # the pinned commit is already here; nothing to fetch
else
  # An older clone may not have the pinned commit yet.
  run git -C "$TPM_DIR" fetch --quiet \
    || log_warn "$PLUGIN_NAME: could not fetch TPM; keeping what is there"
fi
run git -C "$TPM_DIR" checkout --quiet "$TPM_SHA" \
  || log_warn "$PLUGIN_NAME: could not check out TPM at $TPM_SHA; keeping what is there"

true
