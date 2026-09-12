#!/usr/bin/env bash
report ok "flaky" "row one"
[[ -e /definitely/not/here ]] && report ok "flaky extra" "x"
