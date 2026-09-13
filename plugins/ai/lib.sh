#!/usr/bin/env bash
# ai plugin helpers, shared with the tool plugins (claude-code, opencode),
# which source this file as "$NEKOSHELL_PLUGINS_DIR/ai/lib.sh". Both
# functions edit one key of a JSON file the tool owns, through python3,
# writing a temp file beside it and renaming it into place, so the rest of
# the file (the user's own settings) is never rewritten by hand. The previous
# value is recorded in PREVIOUS_FILE the first time only, so a second run (a
# theme switch) never overwrites the user's original with our own value.

# ai_json_set FILE KEY VALUE_JSON PREVIOUS_FILE: set KEY to VALUE_JSON (a
# JSON literal: a quoted string, an object) in FILE, creating FILE when it is
# missing, and record what was there before in PREVIOUS_FILE unless it
# already holds a record for KEY. A dry run only says what it would do.
ai_json_set() {
  local file="$1" key="$2" value="$3" prev="$4"
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would set $key in $file"
    return 0
  fi
  mkdir -p "$(dirname "$file")" "$(dirname "$prev")"
  python3 - "$file" "$key" "$value" "$prev" <<'PY'
import json, os, sys
file, key, value, prev = sys.argv[1:5]
def load(p):
    try:
        with open(p) as f: return json.load(f)
    except (OSError, ValueError): return {}
def save(p, obj):
    tmp = p + ".tmp"
    with open(tmp, "w") as f:
        json.dump(obj, f, indent=2)
        f.write("\n")
    os.replace(tmp, p)
data = load(file)
old = load(prev)
if key not in old:
    old[key] = data.get(key)  # None means "was absent"
    save(prev, old)
data[key] = json.loads(value)
save(file, data)
PY
}

# ai_json_restore FILE KEY PREVIOUS_FILE: put the recorded value of KEY back
# (or drop KEY when there was none) and forget the record. Nothing happens
# when there is no record.
ai_json_restore() {
  local file="$1" key="$2" prev="$3"
  [[ -f "$prev" ]] || return 0
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would restore $key in $file"
    return 0
  fi
  python3 - "$file" "$key" "$prev" <<'PY'
import json, os, sys
file, key, prev = sys.argv[1:4]
def load(p):
    try:
        with open(p) as f: return json.load(f)
    except (OSError, ValueError): return {}
def save(p, obj):
    tmp = p + ".tmp"
    with open(tmp, "w") as f:
        json.dump(obj, f, indent=2)
        f.write("\n")
    os.replace(tmp, p)
old = load(prev)
if key not in old:
    sys.exit(0)
data = load(file)
if old[key] is None:
    data.pop(key, None)
else:
    data[key] = old[key]
del old[key]
save(file, data)
save(prev, old)
PY
}

# ai_json_get FILE KEY: print KEY's value as JSON, or nothing.
ai_json_get() {
  [[ -f "$1" ]] || return 0
  python3 - "$1" "$2" <<'PY'
import json, sys
try:
    with open(sys.argv[1]) as f: data = json.load(f)
except (OSError, ValueError): sys.exit(0)
if sys.argv[2] in data: print(json.dumps(data[sys.argv[2]]))
PY
}
