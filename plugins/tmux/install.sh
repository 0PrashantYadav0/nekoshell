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

if [[ ! -d "$TPM_DIR" ]]; then
  run mkdir -p "$(dirname "$TPM_DIR")"
  run git clone --quiet https://github.com/tmux-plugins/tpm.git "$TPM_DIR"
else
  # An older clone may not have the pinned commit yet.
  run git -C "$TPM_DIR" fetch --quiet
fi
run git -C "$TPM_DIR" checkout --quiet "$TPM_SHA"

true
