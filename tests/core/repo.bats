#!/usr/bin/env bats
# Shape of the repository itself, not of any one script: every plugin and
# every terminal adapter has to present the same surface, and no code may
# still point at the v0.1 layout. These fail loudly with the offending paths
# rather than a bare line number, because that is the whole answer.
load ../helpers

# The nine keys every plugin.toml declares, and the five sections every
# plugin README carries. Both lists are the contract AGENTS.md
# documents; tests/fixtures/plugins/demo is the copyable example.
PLUGIN_KEYS="name summary requires casks taps requires_plugins terminals conflicts tags"
PLUGIN_SECTIONS="What it does:Installs:Files:After install:Remove"
ADAPTER_FUNCS="terminal_name terminal_detect terminal_installed terminal_capabilities terminal_font_name terminal_apply terminal_background terminal_remove terminal_panel terminal_doctor"

@test "every plugin has the nine plugin.toml keys and the five README sections" {
  local bad="" toml dir name key section
  for toml in "$REPO_ROOT"/plugins/*/plugin.toml; do
    dir="$(dirname "$toml")"; name="$(basename "$dir")"
    for key in $PLUGIN_KEYS; do
      grep -qE "^$key[[:space:]]*=" "$toml" || bad="$bad
$name/plugin.toml: missing key '$key'"
    done
    if [[ ! -f "$dir/README.md" ]]; then
      bad="$bad
$name: no README.md"
      continue
    fi
    while IFS=":" read -r section; do
      grep -qF "## $section" "$dir/README.md" || bad="$bad
$name/README.md: missing section '## $section'"
    done < <(printf '%s\n' "$PLUGIN_SECTIONS" | tr ':' '\n')
  done
  if [[ -n "$bad" ]]; then echo "plugin contract violations:$bad" >&2; false; fi
}

@test "every terminal adapter defines the ten adapter functions" {
  local bad="" adapter id fn
  for adapter in "$REPO_ROOT"/terminals/*/adapter.sh; do
    id="$(basename "$(dirname "$adapter")")"
    for fn in $ADAPTER_FUNCS; do
      grep -qE "^$fn\(\)" "$adapter" || bad="$bad
$id/adapter.sh: missing $fn()"
    done
  done
  if [[ -n "$bad" ]]; then echo "adapter contract violations:$bad" >&2; false; fi
}

@test "no code file references the v0.1 layout" {
  # The top-level stow, lib, templates and iterm2 directories are gone. The
  # v0.2 names for the last two live under core and terminals, and the
  # leading "/" keeps them out of the match. Docs are exempt: Phase C
  # rewrites them.
  cd "$REPO_ROOT"
  run grep -rnIE '(^|[^/A-Za-z0-9_.-])(stow|lib|templates|iterm2)/' \
    bin core plugins terminals install.sh uninstall.sh \
    tests/core tests/plugins tests/terminals tests/fixtures tests/helpers.bash
  if [[ "$status" -eq 0 ]]; then
    echo "code still references the v0.1 layout:" >&2
    echo "$output" >&2
    false
  fi
}
