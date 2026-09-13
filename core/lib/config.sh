#!/usr/bin/env bash
# Flat TOML subset for nekoshell.toml and plugin.toml: `key = "string"`,
# `key = ["a", "b"]`, `key = bare`, `# comments`. One key per line, arrays on
# one line, no escapes. Source this file; needs paths.sh for NEKOSHELL_TOML.

# _toml_rhs FILE KEY: print everything after `KEY =` on the first matching line.
_toml_rhs() {
  [[ -r "$1" ]] || return 1
  awk -v k="$2" '
    /^[[:space:]]*#/ { next }
    {
      line = $0; sub(/^[[:space:]]+/, "", line)
      if (index(line, k) != 1) next
      rest = substr(line, length(k) + 1); sub(/^[[:space:]]*/, "", rest)
      if (substr(rest, 1, 1) != "=") next
      rest = substr(rest, 2); sub(/^[[:space:]]*/, "", rest)
      print rest; found = 1; exit
    }
    END { exit found ? 0 : 1 }' "$1"
}

# toml_get FILE KEY: the scalar value, quotes stripped. Status 1 when absent or an array.
toml_get() {
  local rhs
  rhs="$(_toml_rhs "$1" "$2")" || return 1
  case "$rhs" in
    '"'*)
      rhs="${rhs#\"}"
      printf '%s\n' "${rhs%%\"*}"
      ;;
    '['*) return 1 ;;
    *)
      rhs="${rhs%%#*}"
      rhs="${rhs%"${rhs##*[![:space:]]}"}"
      printf '%s\n' "$rhs"
      ;;
  esac
}

# toml_list FILE KEY: array items one per line. Status 0 and no output for an empty or missing array.
toml_list() {
  local rhs
  rhs="$(_toml_rhs "$1" "$2")" || return 0
  case "$rhs" in '['*) ;; *) return 0 ;; esac
  rhs="${rhs#\[}"
  rhs="${rhs%%\]*}"
  printf '%s\n' "$rhs" | awk -F',' '{ for (i = 1; i <= NF; i++) { p = $i; gsub(/^[[:space:]"]+|[[:space:]"]+$/, "", p); if (p != "") print p } }'
}

# _toml_put FILE KEY RAW: replace the line for KEY or append `KEY = RAW`.
_toml_put() {
  local file="$1" key="$2" raw="$3" tmp
  mkdir -p "$(dirname "$file")"
  [[ -f "$file" ]] || : >"$file"
  tmp="$file.tmp.$$"
  awk -v k="$key" -v v="$raw" '
    BEGIN { done = 0 }
    {
      line = $0; sub(/^[[:space:]]+/, "", line)
      if (!done && index(line, k) == 1) {
        rest = substr(line, length(k) + 1); sub(/^[[:space:]]*/, "", rest)
        if (substr(rest, 1, 1) == "=") { print k " = " v; done = 1; next }
      }
      print
    }
    END { if (!done) print k " = " v }' "$file" >"$tmp" && mv "$tmp" "$file"
}

toml_set() { _toml_put "$1" "$2" "\"$3\""; }

# toml_set_list FILE KEY ITEM...: `KEY = ["a", "b"]`; no items gives `KEY = []`.
toml_set_list() {
  local file="$1" key="$2" out="" item
  shift 2
  for item in "$@"; do out="$out${out:+, }\"$item\""; done
  _toml_put "$file" "$key" "[$out]"
}

config_get() { toml_get "$NEKOSHELL_TOML" "$1"; }
config_has() { toml_get "$NEKOSHELL_TOML" "$1" >/dev/null 2>&1 || _toml_rhs "$NEKOSHELL_TOML" "$1" >/dev/null 2>&1; }
config_set() { toml_set "$NEKOSHELL_TOML" "$1" "$2"; }
config_list() { toml_list "$NEKOSHELL_TOML" "$1"; }

config_list_add() {
  local key="$1" item="$2" items=() i
  while IFS= read -r i; do
    [[ "$i" == "$item" ]] && return 0
    items+=("$i")
  done < <(config_list "$key")
  items+=("$item")
  toml_set_list "$NEKOSHELL_TOML" "$key" "${items[@]}"
}

config_list_remove() {
  local key="$1" item="$2" items=() i
  while IFS= read -r i; do [[ "$i" == "$item" ]] || items+=("$i"); done < <(config_list "$key")
  if [[ ${#items[@]} -eq 0 ]]; then toml_set_list "$NEKOSHELL_TOML" "$key"; else toml_set_list "$NEKOSHELL_TOML" "$key" "${items[@]}"; fi
}
