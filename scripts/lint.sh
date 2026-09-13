#!/usr/bin/env bash
# lint.sh: every static check the repository runs, in one place. CI calls
# this, the pre-commit hook calls this on the staged files, and `make lint`
# calls it by hand, so the three can never disagree about what "clean" means.
#
#   scripts/lint.sh            check the whole tree
#   scripts/lint.sh FILE...    check only FILE... (what the pre-commit hook does)
#   scripts/lint.sh --fix      rewrite shell files with shfmt instead of reporting
#
# Checks, in order: shellcheck, shfmt, the repository's own shape rules,
# actionlint on the workflows, yamllint, markdownlint. A missing linter is a
# failure on CI (NEKOSHELL_LINT_STRICT=1) and a warning on a laptop, so a
# contributor without every tool installed still gets the checks they have.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$root"

fix=0
files=()
for arg in "$@"; do
  case "$arg" in
    --fix) fix=1 ;;
    -h | --help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) files+=("$arg") ;;
  esac
done

strict="${NEKOSHELL_LINT_STRICT:-0}"
failed=0
red=$'\033[31m' yellow=$'\033[33m' green=$'\033[32m' reset=$'\033[0m'
[[ -t 1 ]] || red="" yellow="" green="" reset=""
fail() {
  printf '%sfail%s %s\n' "$red" "$reset" "$*" >&2
  failed=1
}
skip() {
  if [[ "$strict" == 1 ]]; then fail "$1 is not installed"; else printf '%sskip%s %s not installed\n' "$yellow" "$reset" "$1"; fi
}
ok() { printf '%sok%s   %s\n' "$green" "$reset" "$*"; }

# is_shell FILE: a shell script by extension or by shebang. bats files are
# checked separately (shellcheck does not parse @test blocks).
is_shell() {
  case "$1" in
    *.sh | *.bash) return 0 ;;
    *.bats | *.py | *.md | *.json | *.yml | *.yaml | *.toml | *.txt) return 1 ;;
  esac
  [[ -f "$1" ]] && head -n 1 "$1" | grep -qE '^#!.*\b(ba)?sh\b'
}

# all_shell: every shell file git knows about, one per line.
all_shell() {
  local f
  while IFS= read -r f; do is_shell "$f" && printf '%s\n' "$f"; done < <(git ls-files) || true
  return 0
}

shell_files=()
md_files=()
yaml_files=()
if [[ ${#files[@]} -gt 0 ]]; then
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    if is_shell "$f"; then shell_files+=("$f"); fi
    case "$f" in
      *.md) md_files+=("$f") ;;
      *.yml | *.yaml) yaml_files+=("$f") ;;
    esac
  done
else
  while IFS= read -r f; do [[ -n "$f" ]] && shell_files+=("$f"); done < <(all_shell)
  while IFS= read -r f; do [[ -n "$f" ]] && md_files+=("$f"); done < <(git ls-files '*.md')
  while IFS= read -r f; do [[ -n "$f" ]] && yaml_files+=("$f"); done < <(git ls-files '*.yml' '*.yaml')
fi

# --- shellcheck -------------------------------------------------------------
if [[ ${#shell_files[@]} -gt 0 ]]; then
  if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck -x "${shell_files[@]}"; then ok "shellcheck (${#shell_files[@]} files)"; else fail "shellcheck"; fi
  else
    skip shellcheck
  fi
fi

# --- shfmt ------------------------------------------------------------------
# -i 2 two-space indent, -ci indent case arms, -bn binary operators may start
# a line. The same flags the pre-commit hook and CONTRIBUTING.md name.
if [[ ${#shell_files[@]} -gt 0 ]]; then
  if command -v shfmt >/dev/null 2>&1; then
    if [[ "$fix" == 1 ]]; then
      shfmt -w -i 2 -ci -bn "${shell_files[@]}"
      ok "shfmt rewrote what it had to"
    elif out="$(shfmt -l -i 2 -ci -bn "${shell_files[@]}")" && [[ -z "$out" ]]; then
      ok "shfmt (${#shell_files[@]} files)"
    else
      printf '%s\n' "$out" >&2
      fail "shfmt: the files above need formatting; run: scripts/lint.sh --fix"
    fi
  else
    skip shfmt
  fi
fi

# --- repository shape --------------------------------------------------------
# Rules the tests also enforce (tests/core/repo.bats), repeated here so a
# commit that breaks them is refused before the suite runs: every executable
# under bin/ and plugins/*/bin is executable; no shell file carries a CRLF or
# a tab-indented line; every plugin.toml has the nine keys; every terminal
# adapter has the ten functions.
shape_failed=0
while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  [[ -x "$f" ]] || {
    echo "$f: not executable" >&2
    shape_failed=1
  }
done < <(git ls-files 'bin/*' 'plugins/*/bin/*' 'tests/fakes/*' 'install.sh' 'uninstall.sh' 'scripts/*')
# Guarded: bash 3.2 treats an empty array as unbound under `set -u`, and a
# commit of only docs has no shell files at all.
if [[ ${#shell_files[@]} -gt 0 ]]; then
  for f in "${shell_files[@]}"; do
    if grep -q $'\r' "$f"; then
      echo "$f: CRLF line endings" >&2
      shape_failed=1
    fi
  done
fi
for toml in plugins/*/plugin.toml tests/fixtures/plugins/*/plugin.toml; do
  [[ -f "$toml" ]] || continue
  for key in name summary requires casks taps requires_plugins terminals conflicts tags; do
    grep -qE "^${key}[[:space:]]*=" "$toml" || {
      echo "$toml: missing key '$key'" >&2
      shape_failed=1
    }
  done
done
for adapter in terminals/*/adapter.sh; do
  for fn in terminal_name terminal_detect terminal_installed terminal_capabilities terminal_font_name terminal_apply terminal_background terminal_remove terminal_panel terminal_doctor; do
    grep -qE "^$fn\(\)" "$adapter" || {
      echo "$adapter: missing $fn()" >&2
      shape_failed=1
    }
  done
done
if [[ "$shape_failed" == 0 ]]; then ok "repository shape"; else fail "repository shape"; fi

# --- actionlint ---------------------------------------------------------------
if ls .github/workflows/*.yml >/dev/null 2>&1; then
  if command -v actionlint >/dev/null 2>&1; then
    if actionlint; then ok "actionlint"; else fail "actionlint"; fi
  else
    skip actionlint
  fi
fi

# --- yamllint -----------------------------------------------------------------
if [[ ${#yaml_files[@]} -gt 0 ]]; then
  if command -v yamllint >/dev/null 2>&1; then
    if yamllint -c .yamllint.yaml "${yaml_files[@]}"; then ok "yamllint (${#yaml_files[@]} files)"; else fail "yamllint"; fi
  else
    skip yamllint
  fi
fi

# --- markdownlint -------------------------------------------------------------
if [[ ${#md_files[@]} -gt 0 ]]; then
  if command -v markdownlint-cli2 >/dev/null 2>&1; then
    if markdownlint-cli2 "${md_files[@]}"; then ok "markdownlint (${#md_files[@]} files)"; else fail "markdownlint"; fi
  else
    skip markdownlint-cli2
  fi
fi

exit "$failed"
