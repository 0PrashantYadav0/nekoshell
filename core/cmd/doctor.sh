#!/usr/bin/env bash
# doctor: one line per check; exit 1 iff any check fails
usage_doctor() {
  cat <<'EOF'
usage: nekoshell doctor [--json] [--plugin NAME]
EOF
}

# report STATUS NAME DETAIL: shared with terminal adapters (terminal_doctor)
# and plugin doctor.sh hooks, which call it directly — it is defined here, in
# cmd_doctor, and inherited by every function and subshell run underneath it
# (plugin_run_hook's subshell included), so there is exactly one row format
# and one place rows are collected.
_doctor_rows_file=""
_doctor_tmp_files=()

report() {
  # Rows land in a file, not an in-memory array: plugin hooks run inside
  # plugin_run_hook's `( ... )` subshell, and a subshell's variable changes
  # never reach back out to the parent shell, but a file write does. Detail
  # is flattened to one line first: a tab or newline in it would otherwise be
  # mistaken for a field or row separator when the file is read back.
  local detail="${3//$'\t'/ }"
  detail="${detail//$'\n'/ }"
  printf '%s\t%s\t%s\n' "$1" "$2" "$detail" >>"$_doctor_rows_file"
}

cmd_doctor() {
  local json=0 only_plugin=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json)
        json=1
        shift
        ;;
      --plugin)
        [[ -n "${2:-}" ]] || {
          usage_doctor
          return 2
        }
        only_plugin="$2"
        shift 2
        ;;
      -h | --help | help)
        usage_doctor
        return 0
        ;;
      *)
        usage_doctor
        return 2
        ;;
    esac
  done

  _doctor_rows_file="$(mktemp "${TMPDIR:-/tmp}/nekoshell-doctor.XXXXXX")"
  # A RETURN trap can be skipped when `set -e` unwinds the function instead of
  # letting it reach its own `return`; EXIT always fires. The trap removes
  # every file this process's doctors made, not just the latest: install runs
  # cmd_doctor inside its own process, and a second trap would otherwise
  # replace the first and leak its file.
  _doctor_tmp_files+=("$_doctor_rows_file")
  trap '_doctor_cleanup' EXIT

  if [[ -n "$only_plugin" ]]; then
    _doctor_plugin_block "$only_plugin"
  else
    _doctor_core_block
    _doctor_terminal_block
    local p
    for p in $(plugin_enabled_all); do
      _doctor_plugin_block "$p"
    done
  fi

  local fails=0 status check detail
  while IFS=$'\t' read -r status check detail; do
    [[ "$status" == "fail" ]] && fails=$((fails + 1))
  done <"$_doctor_rows_file"

  if [[ "$json" == 1 ]]; then
    python3 - "$_doctor_rows_file" <<'PY'
import json, sys
rows = []
with open(sys.argv[1], encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        if not line:
            continue
        status, check, detail = line.split("\t", 2)
        rows.append({"status": status, "check": check, "detail": detail})
print(json.dumps(rows))
PY
  else
    while IFS=$'\t' read -r status check detail; do
      printf '%-4s %-28s %s\n' "$status" "$check" "$detail"
    done <"$_doctor_rows_file"
  fi

  [[ "$fails" -eq 0 ]]
}

_doctor_cleanup() {
  [[ ${#_doctor_tmp_files[@]} -gt 0 ]] && rm -f "${_doctor_tmp_files[@]}"
  return 0
}

_doctor_have() { command -v "$1" >/dev/null 2>&1; }

# _doctor_font_file: the first JetBrainsMono Nerd Font file found, or nothing.
_doctor_font_file() {
  local f
  for f in "$HOME"/Library/Fonts/JetBrainsMonoNerdFont* /Library/Fonts/JetBrainsMonoNerdFont*; do
    [[ -e "$f" ]] && {
      printf '%s\n' "$f"
      return 0
    }
  done
  return 1
}

# _doctor_font_glyphs FONTFILE: does the font's cmap carry Nerd Fonts v3 icons
# (checked via U+F00BA, one of the glyphs eza uses)? Parses the TrueType cmap
# table by hand: no Python font library is guaranteed to be installed.
#
# The parser distinguishes "the font was read and the glyph is missing" (a
# real fail) from "this file could not be parsed as a TrueType/OpenType font"
# (a warn, not a fail: a .ttc collection, a corrupt download, or anything
# else struct.unpack chokes on is not evidence the Nerd Font is missing, only
# that this simple hand-rolled parser could not read it). Exit codes: 0 =
# glyph present, 1 = parsed fine, glyph absent, 2 = could not parse.
_doctor_font_glyphs() {
  local fontfile="$1" rc
  if ! command -v python3 >/dev/null 2>&1; then
    report warn "font glyphs" "python3 missing; glyph check skipped"
    return 0
  fi
  if python3 - "$fontfile" 2>/dev/null <<'EOF'
import struct, sys
try:
    data = open(sys.argv[1], 'rb').read()
    n = struct.unpack('>H', data[4:6])[0]
    found = False
    for i in range(n):
        tag, _, off, ln = struct.unpack('>4sIII', data[12+16*i:28+16*i])
        if tag == b'cmap':
            cmap = data[off:off+ln]
            sub = struct.unpack('>H', cmap[2:4])[0]
            for j in range(sub):
                pid, eid, o = struct.unpack('>HHI', cmap[4+8*j:12+8*j])
                fmt = struct.unpack('>H', cmap[o:o+2])[0]
                if fmt == 12:
                    ngroups = struct.unpack('>I', cmap[o+12:o+16])[0]
                    for g in range(ngroups):
                        s, e, _ = struct.unpack('>III', cmap[o+16+12*g:o+28+12*g])
                        if s <= 0xF00BA <= e:
                            found = True
                            break
                if found:
                    break
        if found:
            break
except Exception:
    sys.exit(2)
sys.exit(0 if found else 1)
EOF
  then
    rc=0
  else
    rc=$?
  fi
  case "$rc" in
    0) report ok "font glyphs" "Nerd Fonts v3 (U+F00BA present)" ;;
    1) report fail "font glyphs" "font lacks Nerd Fonts v3 icons; eza icons will show as boxes" ;;
    *) report warn "font glyphs" "could not read the font file" ;;
  esac
}

_doctor_core_block() {
  if _doctor_have brew; then report ok "homebrew" "$(brew --version | head -1)"; else report fail "homebrew" "not on PATH"; fi

  if [[ -L "$HOME/.zshrc" ]] && [[ "$HOME/.zshrc" -ef "$NEKOSHELL_ROOT/core/zsh/.zshrc" ]]; then
    report ok "zshrc" "linked to $NEKOSHELL_ROOT"
  else
    report fail "zshrc" "not a nekoshell symlink (run: nekoshell install)"
  fi

  if [[ -r "$NEKOSHELL_TOML" ]] && [[ "$(config_get root 2>/dev/null || true)" == "$NEKOSHELL_ROOT" ]]; then
    report ok "config" "$NEKOSHELL_TOML"
  else
    report fail "config" "stale root (run: nekoshell install)"
  fi

  if _doctor_have starship; then report ok "starship" "$(command -v starship)"; else report fail "starship" "missing (run: nekoshell install)"; fi

  # antidote is a zsh script under Homebrew's prefix, not a command, so the
  # zshrc's own lookup is repeated here. The row warns rather than fails: the
  # shell still starts without it, with no plugins loaded.
  local prefix
  prefix="${HOMEBREW_PREFIX:-$(brew --prefix 2>/dev/null || echo /opt/homebrew)}"
  if [[ -r "$prefix/opt/antidote/share/antidote/antidote.zsh" ]]; then
    report ok "zsh plugin manager" "antidote at $prefix/opt/antidote"
  else
    report warn "zsh plugin manager" "antidote not installed (run: nekoshell install)"
  fi

  local fontfile=""
  fontfile="$(_doctor_font_file || true)"
  if [[ -n "$fontfile" ]]; then
    report ok "font" "$fontfile"
    _doctor_font_glyphs "$fontfile"
  else
    report warn "font" "not installed (brew install --cask font-jetbrains-mono-nerd-font)"
  fi

  report ok "theme" "$(theme_current)"

  if [[ -r "$NEKOSHELL_CONFIG/antidote.txt" ]]; then
    report ok "antidote" "$NEKOSHELL_CONFIG/antidote.txt"
  else
    report warn "antidote" "not generated yet (run: nekoshell plugin add ...)"
  fi
}

# One block per configured terminal, so a machine that uses several sees
# every one of them checked, not only the one this doctor happens to run in.
_doctor_terminal_block() {
  local term any=0
  for term in $(terminal_configured_all); do
    any=1
    if terminal_load "$term"; then
      # A terminal_doctor whose last command is a guarded, legitimately-false
      # check (e.g. `[[ -e some/optional/file ]] && report ...`) would
      # otherwise exit non-zero and, under bin/nekoshell's `set -e`, take the
      # rest of the doctor down with it. One bad adapter must not silence
      # every other row.
      terminal_doctor || report warn "$term" "terminal doctor hook failed"
    else
      report fail "terminal" "no adapter named $term"
    fi
  done
  [[ "$any" == 1 ]] || report warn "terminal" "none configured (run: nekoshell terminal use <id>)"
  return 0
}

_doctor_plugin_block() {
  local name="$1"
  plugin_exists "$name" || {
    report fail "$name" "no such plugin"
    return 0
  }
  # Same reasoning as terminal_doctor above: a plugin's doctor.sh ending on a
  # guarded, legitimately-false check must warn, not abort every other block.
  plugin_run_hook "$name" doctor || report warn "$name" "doctor hook failed"
}
