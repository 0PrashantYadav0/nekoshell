#!/usr/bin/env bash
# ai: preview and edit the welcome banner, see which tool plugins are on
usage_ai() {
  cat <<'USAGE'
usage: nekoshell ai welcome [TOOL]   print the banner as TOOL would see it (claude-code)
       nekoshell ai edit            open the banner template in your editor
       nekoshell ai status          the tool plugins, their binaries and templates

The banner is ~/.config/nekoshell/ai/welcome.txt (welcome-norepo.txt outside
a repository); a welcome.TOOL.txt beside it wins for that tool. Placeholders:
@@TOOL@@ @@PROJECT@@ @@BRANCH@@ @@COMMIT@@ @@SUBJECT@@ @@WHEN@@ @@DIR@@.
NEKOSHELL_AI_WELCOME=0 switches the banner off.
USAGE
}

# _ai_status: one line per tool plugin: enabled or not, the binary, the
# per-tool template.
_ai_status() {
  local tool bin state where tmpl
  for tool in claude-code opencode; do
    case "$tool" in
      claude-code) bin=claude ;;
      *) bin="$tool" ;;
    esac
    if plugin_enabled "$tool"; then state="enabled"; else state="not enabled"; fi
    where="$(command -v "$bin" 2>/dev/null || echo "not on PATH")"
    tmpl="shared template"
    [[ -r "$NEKOSHELL_CONFIG/ai/welcome.$tool.txt" ]] && tmpl="welcome.$tool.txt"
    printf '%-12s %-12s %-40s %s\n' "$tool" "$state" "$where" "$tmpl"
  done
}

cmd_ai() {
  local sub="${1:-}"
  [[ $# -gt 0 ]] && shift
  case "$sub" in
    welcome)
      [[ $# -le 1 ]] || {
        usage_ai >&2
        return 2
      }
      NEKOSHELL_AI_WELCOME_FORCE=1 exec "$PLUGIN_DIR/bin/nekoshell-ai-welcome" "${1:-claude-code}"
      ;;
    edit)
      [[ -f "$NEKOSHELL_CONFIG/ai/welcome.txt" ]] || {
        log_fail "$NEKOSHELL_CONFIG/ai/welcome.txt is missing; run: nekoshell plugin add ai"
        return 1
      }
      exec "${EDITOR:-nvim}" "$NEKOSHELL_CONFIG/ai/welcome.txt"
      ;;
    status) _ai_status ;;
    -h | --help | help)
      usage_ai
      return 0
      ;;
    *)
      usage_ai >&2
      return 2
      ;;
  esac
}
