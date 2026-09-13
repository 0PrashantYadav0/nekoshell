#!/usr/bin/env bash
# claude-code install: Claude Code is usually installed by its own installer
# or through npm, and a Homebrew cask would put a second copy beside it, so
# the plugin installs nothing and only says how when the binary is missing.

if ! command -v claude >/dev/null 2>&1; then
  log_warn "$PLUGIN_NAME: claude is not on PATH; install it with: brew install --cask claude-code (or curl -fsSL https://claude.ai/install.sh | bash)"
fi

true
