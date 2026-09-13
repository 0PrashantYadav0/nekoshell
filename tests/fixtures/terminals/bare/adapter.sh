#!/usr/bin/env bash
# The smallest adapter there is: a name, and every other function left as the
# default from terminals/adapter.sh. This is what the contract's own defaults
# are tested through, so a fixture that overrides one of them (fake) cannot
# quietly hide a broken default.
terminal_name() { echo bare; }
