#!/usr/bin/env bash
# vscode plugin helpers, shared by its hooks, which source this file as
# "$PLUGIN_DIR/lib.sh"; do not execute it. Where VS Code keeps its user
# settings, which app bundle VS Code wants for each nekoshell terminal id,
# and an editor for that settings file.
#
# The editor is not ai_json_set from plugins/ai/lib.sh. VS Code's
# settings.json is JSONC: comments and trailing commas are allowed, and
# people keep both in there. ai_json_set parses strict JSON and treats a file
# it cannot parse as empty, which would rewrite a commented file down to our
# two keys. These functions work on the text instead: one line replaced or
# inserted, everything else kept byte for byte.
#
# The constants are read by the files that source this one, which shellcheck
# cannot see from here.
# shellcheck disable=SC2034

# NEKOSHELL_VSCODE_SETTINGS is for tests, and for Insiders, VSCodium and
# Cursor, which keep the same file under another name. NEKOSHELL_VSCODE_APP is
# for tests: a Mac that has VS Code in /Applications cannot otherwise pretend
# it has not.
VSCODE_SETTINGS="${NEKOSHELL_VSCODE_SETTINGS:-$HOME/Library/Application Support/Code/User/settings.json}"
VSCODE_APP="${NEKOSHELL_VSCODE_APP:-/Applications/Visual Studio Code.app}"
VSCODE_PREVIOUS="$NEKOSHELL_CONFIG/vscode/previous.json"
VSCODE_CASK="brew install --cask visual-studio-code"

# vscode_app_for ID: the app bundle name VS Code's terminal.external.osxExec
# takes for a nekoshell terminal id. Status 1 for an id with no entry. The
# table lives here and not in the terminal adapters: the adapter contract is
# ten functions exactly, and this plugin is the table's only reader.
vscode_app_for() {
  case "$1" in
    kitty) echo "kitty.app" ;;
    ghostty) echo "Ghostty.app" ;;
    iterm2) echo "iTerm.app" ;;
    warp) echo "Warp.app" ;;
    terminal-app) echo "Terminal.app" ;;
    *) return 1 ;;
  esac
}

# vscode_installed: `code` on PATH or the app bundle in either Applications
# directory.
vscode_installed() {
  command -v code >/dev/null 2>&1 \
    || [[ -e "$VSCODE_APP" || -e "$HOME/Applications/Visual Studio Code.app" ]]
}

# vscode_installed_where: the path vscode_installed found, for the doctor.
vscode_installed_where() {
  if command -v code >/dev/null 2>&1; then
    command -v code
  elif [[ -e "$VSCODE_APP" ]]; then
    echo "$VSCODE_APP"
  else
    echo "$HOME/Applications/Visual Studio Code.app"
  fi
}

# vscode_debug_supported APP: whether `"console": "externalTerminal"` in a
# launch.json can open APP. VS Code scripts that launch itself and knows
# three apps (src/vs/platform/externalTerminal/node/externalTerminalService.ts);
# anything else fails inside VS Code with "'X.app' not supported".
vscode_debug_supported() {
  case "$1" in
    Terminal.app | iTerm.app | Ghostty.app) return 0 ;;
  esac
  return 1
}

# _vscode_json OP FILE KEY VALUE PREV: the one python program behind the
# three functions below. OP is get, set or restore.
#
# The text is tokenised once (strings, comments, punctuation, bare scalars)
# and the top-level keys are located by brace depth, so a key of the same
# name nested inside another object is never mistaken for ours. `get` joins
# the tokens back without the comments and trailing commas and parses that.
# `set` and `restore` splice the text: a found key has its value replaced in
# place; a missing key is inserted after the opening brace on a line of its
# own; a removed key takes its line with it, and the comma of the entry
# before it when it was the last one.
_vscode_json() {
  python3 - "$@" <<'PY'
import json, os, re, sys
op, file, key, value, prev = sys.argv[1:6]

def tokens(text):
    """(kind, start, end) over text: str, punct, scalar; comments and
    whitespace are skipped. end is exclusive."""
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c.isspace():
            i += 1
        elif text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j == -1 else j
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j == -1 else j + 2
        elif c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            yield ("str", i, min(j + 1, n))
            i = j + 1
        elif c in "{}[]:,":
            yield ("punct", i, i + 1)
            i += 1
        else:
            j = i
            while j < n and not text[j].isspace() and text[j] not in '{}[]:,"' and not text.startswith("//", j) and not text.startswith("/*", j):
                j += 1
            yield ("scalar", i, max(j, i + 1))
            i = max(j, i + 1)

def scan(text):
    """The top object's opening brace, its closing brace, and one entry per
    top-level key: (key, key_start, value_start, value_end)."""
    toks = list(tokens(text))
    if not toks or text[toks[0][1]] != "{":
        return None, None, []
    open_pos = toks[0][1]
    close_pos = None
    entries = []
    depth = 0
    k = 0
    while k < len(toks):
        kind, s, e = toks[k]
        ch = text[s:e]
        if kind == "punct" and ch in "{[":
            depth += 1
        elif kind == "punct" and ch in "}]":
            depth -= 1
            if depth == 0:
                close_pos = s
                break
        elif depth == 1 and kind == "str" and k + 1 < len(toks) and text[toks[k + 1][1]] == ":":
            name = json.loads(ch)
            k += 2
            if k >= len(toks):
                break
            vs = toks[k][1]
            ve = toks[k][2]
            if text[vs] in "{[":
                d = 0
                while k < len(toks):
                    t = text[toks[k][1]:toks[k][2]]
                    if toks[k][0] == "punct" and t in "{[":
                        d += 1
                    elif toks[k][0] == "punct" and t in "}]":
                        d -= 1
                        if d == 0:
                            ve = toks[k][2]
                            break
                    k += 1
            entries.append((name, s, vs, ve))
        k += 1
    return open_pos, close_pos, entries

def parse(text):
    """The top object as a dict, or None when the text is not one."""
    out = []
    toks = list(tokens(text))
    for k, (kind, s, e) in enumerate(toks):
        if kind == "punct" and text[s] == "," and k + 1 < len(toks) and text[toks[k + 1][1]] in "}]":
            continue
        out.append(text[s:e])
    try:
        data = json.loads(" ".join(out)) if out else {}
    except ValueError:
        return None
    return data if isinstance(data, dict) else None

def read(p):
    try:
        with open(p) as f:
            return f.read()
    except OSError:
        return ""

def write(p, text):
    tmp = p + ".tmp"
    with open(tmp, "w") as f:
        f.write(text)
    os.replace(tmp, p)

def load_prev():
    try:
        with open(prev) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}

def save_prev(obj):
    tmp = prev + ".tmp"
    with open(tmp, "w") as f:
        json.dump(obj, f, indent=2)
        f.write("\n")
    os.replace(tmp, prev)

def put(text, literal):
    """text with key set to literal (a JSON literal, verbatim)."""
    if not text.strip():
        return '{\n  "%s": %s\n}\n' % (key, literal)
    open_pos, close_pos, entries = scan(text)
    if open_pos is None or close_pos is None:
        sys.exit("%s: not a JSON object; nothing written" % file)
    for name, ks, vs, ve in entries:
        if name == key:
            return text[:vs] + literal + text[ve:]
    indent = "  "
    if entries:
        ks = entries[0][1]
        ls = text.rfind("\n", 0, ks) + 1
        indent = text[ls:ks] if text[ls:ks].isspace() else "  "
    line = '%s"%s": %s' % (indent, key, literal)
    eol = text.find("\n", open_pos + 1)
    rest = text[open_pos + 1:eol] if eol != -1 else text[open_pos + 1:]
    if eol != -1 and (not rest.strip() or rest.lstrip().startswith("//")):
        # The brace ends its line: the new entry goes on the next one.
        return text[:eol + 1] + line + (",\n" if entries else "\n") + text[eol + 1:]
    # Something follows the brace on its own line ({} or a one-liner).
    return text[:open_pos + 1] + "\n" + line + (", " if entries else "\n") + text[open_pos + 1:]

def drop(text):
    """text without key's entry, or unchanged when there is none."""
    open_pos, close_pos, entries = scan(text)
    for i, (name, ks, vs, ve) in enumerate(entries):
        if name != key:
            continue
        ls = text.rfind("\n", 0, ks) + 1
        le = text.find("\n", ve)
        le = len(text) if le == -1 else le + 1
        head, tail = text[ls:ks], text[ve:le]
        if not head.strip() and re.match(r"^\s*,?\s*(//.*)?\n?$", tail):
            start, end = ls, le
        else:
            m = re.match(r"\s*,\s*", text[ve:])
            start, end = ks, ve + (m.end() if m else 0)
        text = text[:start] + text[end:]
        if i == len(entries) - 1 and i > 0:
            # It was the last entry: the comma after the one before it now
            # trails, which JSONC allows but strict JSON does not.
            pve = entries[i - 1][3]
            m = re.match(r"\s*,", text[pve:])
            if m:
                comma = pve + m.end() - 1
                text = text[:comma] + text[comma + 1:]
        return text
    return text

text = read(file)
if op == "get":
    data = parse(text)
    if data is not None and key in data:
        print(json.dumps(data[key]))
elif op == "set":
    old = load_prev()
    if key not in old:
        data = parse(text) or {}
        old[key] = data.get(key)
        save_prev(old)
    write(file, put(text, value))
elif op == "restore":
    old = load_prev()
    if key not in old:
        sys.exit(0)
    if old[key] is None:
        if text.strip():
            write(file, drop(text))
    else:
        write(file, put(text, json.dumps(old[key])))
    del old[key]
    save_prev(old)
PY
}

# vscode_json_get FILE KEY: print the value of top-level KEY as JSON, or
# nothing when FILE is missing, unparseable, or has no KEY.
vscode_json_get() {
  [[ -f "$1" ]] || return 0
  _vscode_json get "$1" "$2" "" ""
}

# vscode_json_set FILE KEY VALUE PREV: set top-level KEY to VALUE (a JSON
# literal: a quoted string, a number) in FILE, creating FILE when it is
# missing, and record what was there before in PREV (null for absent) unless
# PREV already holds a record for KEY, so a second run never overwrites the
# user's original with our own value. A dry run only says what it would do.
vscode_json_set() {
  local file="$1" key="$2" value="$3" prev="$4"
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would set $key to $value in $file"
    return 0
  fi
  mkdir -p "$(dirname "$file")" "$(dirname "$prev")"
  _vscode_json set "$file" "$key" "$value" "$prev"
}

# vscode_json_restore FILE KEY PREV: put the recorded value of KEY back, or
# remove KEY's line when the record says it was absent, and forget the
# record. Nothing happens when there is no record.
vscode_json_restore() {
  local file="$1" key="$2" prev="$3"
  [[ -f "$prev" ]] || return 0
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would restore $key in $file"
    return 0
  fi
  _vscode_json restore "$file" "$key" "" "$prev"
}
