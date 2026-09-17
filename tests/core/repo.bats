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
  # A ":" before the name is excluded too: antidote's `path:lib/git.zsh`
  # names a directory inside oh-my-zsh, not the old core library tree.
  run grep -rnIE '(^|[^/A-Za-z0-9_.:-])(stow|lib|templates|iterm2)/' \
    bin core plugins terminals install.sh uninstall.sh \
    tests/core tests/plugins tests/terminals tests/fixtures tests/helpers.bash
  if [[ "$status" -eq 0 ]]; then
    echo "code still references the v0.1 layout:" >&2
    echo "$output" >&2
    false
  fi
}

# An art provider is a plugin with an executable greet-art; the greeting runs
# it on every shell, so it has to be runnable and has to depend on greet.
@test "every art provider is executable and requires greet" {
  local bad="" art dir name
  for art in "$REPO_ROOT"/plugins/*/greet-art; do
    [[ -e "$art" ]] || continue
    dir="$(dirname "$art")"; name="$(basename "$dir")"
    [[ -x "$art" ]] || bad="$bad
$name/greet-art: not executable"
    grep -qE '^requires_plugins *= *\[.*"greet".*\]' "$dir/plugin.toml" || bad="$bad
$name/plugin.toml: an art provider must list greet in requires_plugins"
  done
  if [[ -n "$bad" ]]; then echo "art provider contract violations:$bad" >&2; false; fi
}

# The release tarball is `git archive` of the tag. Development-only files stay
# out of it through export-ignore, and the tree that ships must still run.
@test "git archive of HEAD ships the runtime and not the development files" {
  cd "$REPO_ROOT"
  run bash -c "git archive --worktree-attributes --format=tar HEAD | tar -t"
  [ "$status" -eq 0 ]
  assert_contains "$output" "bin/nekoshell"
  assert_contains "$output" "VERSION"
  assert_contains "$output" "docs/plugins/README.md"
  assert_not_contains "$output" ".github/"
  assert_not_contains "$output" ".githooks/"
  assert_not_contains "$output" ".shellcheckrc"
  # Top-level only: plugins/colorscripts/scripts.txt and the like are runtime
  # files that happen to share a name with the directories going.
  local top; top="$(printf '%s\n' "$output" | grep -E '^(tests|scripts|skills|packaging)/' || true)"
  [ -z "$top" ]
  local root; root="$(printf '%s\n' "$output" | grep -E '^(Makefile|AGENTS\.md|CLAUDE\.md|llms\.txt)$' || true)"
  [ -z "$root" ]
}

# The user manual is one page per plugin plus a table that links them, and a
# profile is a list of plugin names. Each of those goes stale silently.
@test "every plugin has a docs page and a row in docs/plugins/README.md" {
  local bad="" dir name
  for dir in "$REPO_ROOT"/plugins/*/; do
    name="$(basename "$dir")"
    [[ -f "$REPO_ROOT/docs/plugins/$name.md" ]] || bad="$bad
docs/plugins/$name.md: missing"
    grep -qE "\($name\.md\)" "$REPO_ROOT/docs/plugins/README.md" || bad="$bad
docs/plugins/README.md: no link to $name.md"
  done
  if [[ -n "$bad" ]]; then echo "plugin docs out of step:$bad" >&2; false; fi
}

@test "every docs page has the five user headings" {
  local bad="" page h
  for page in "$REPO_ROOT"/docs/plugins/*.md; do
    [[ "$(basename "$page")" == "README.md" || "$(basename "$page")" == "ARCHITECTURE.md" ]] && continue
    for h in "## What you get" "## Using it" "## Files" "## Theme" "## Turning it off"; do
      grep -qF "$h" "$page" || bad="$bad
$(basename "$page"): missing '$h'"
    done
  done
  if [[ -n "$bad" ]]; then echo "plugin page headings:$bad" >&2; false; fi
}

@test "every profile names plugins that exist" {
  local bad="" profile name
  for profile in "$REPO_ROOT"/profiles/*.txt; do
    while IFS= read -r name; do
      [[ -n "$name" ]] || continue
      [[ -d "$REPO_ROOT/plugins/$name" ]] || bad="$bad
$(basename "$profile"): no plugin named $name"
    done < "$profile"
  done
  if [[ -n "$bad" ]]; then echo "profile violations:$bad" >&2; false; fi
}

# macOS grep (BSD) has no \b; GNU does. grep -w works on both, and "-" is a
# non-word character on either side so modern-cli still matches with -w.
@test "the README names every plugin" {
  local bad="" dir name
  for dir in "$REPO_ROOT"/plugins/*/; do
    name="$(basename "$dir")"
    grep -qw "$name" "$REPO_ROOT/README.md" || bad="$bad
README.md does not mention $name"
  done
  if [[ -n "$bad" ]]; then echo "readme:$bad" >&2; false; fi
}
