# AI Tool Plugins Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A shared `ai` plugin that prints a welcome banner (tool, project, branch, last commit) before an AI coding tool starts, and two tool plugins, `claude-code` and `opencode`, that theme those tools in the flavour and wrap them with the banner.

**Architecture:** `ai` owns the banner program, its templates and `nekoshell ai`. Each tool plugin depends on it (`requires_plugins = ["ai"]`), defines a zsh function of the tool's name that prints the banner and execs the real binary, and renders that tool's theme on every flavour switch. Keys the tools keep in their own JSON files (`theme` and `statusLine` in `~/.claude/settings.json`, `theme` in `~/.config/opencode/tui.json`) are set one key at a time with the previous value recorded, and restored on removal.

**Tech Stack:** bash 3.2, zsh, python3 (json edits), Claude Code 2.1.x (custom themes in `~/.claude/themes/*.json`, `theme` and `statusLine` settings), OpenCode 1.x (`~/.config/opencode/themes/*.json`, `tui.json`).

**Spec:** `docs/superpowers/specs/2026-09-13-art-providers-and-plugins-design.md`, section 3. Since the spec: Claude Code supports custom theme files (`~/.claude/themes/<slug>.json`, `theme = "custom:<slug>"` in settings.json), so the plugin renders a real Catppuccin theme rather than picking dark or light; `claude config set` no longer exists in 2.1.x, so settings.json is edited directly, one key.

## Global Constraints

- As the other plans, plus: a wrapper function never gets in the way of a non-interactive use (`claude -p`, `opencode run`, `--version`, `--help`) and never runs when stdout is not a tty.
- JSON files of the tools are edited by python3's json module: read, set one key, write to a temp file beside it, rename. The previous value is recorded once in `~/.config/nekoshell/ai/<tool>-previous.json` and put back on uninstall.
- Branch: `feat/ai-plugins`.

---

### Task 1: The `ai` plugin

**Files:**

- Create: `plugins/ai/plugin.toml`, `plugins/ai/bin/nekoshell-ai-welcome`, `plugins/ai/lib.sh`, `plugins/ai/cmd/ai.sh`, `plugins/ai/theme.sh`, `plugins/ai/doctor.sh`, `plugins/ai/README.md`, `plugins/ai/files/colors.sh.tmpl`, `plugins/ai/files/copy/.config/nekoshell/ai/welcome.txt`, `plugins/ai/files/copy/.config/nekoshell/ai/welcome-norepo.txt`, `docs/plugins/ai.md`
- Test: `tests/plugins/ai.bats`

**Interfaces:**

- Produces: `nekoshell-ai-welcome TOOL` (on the plugin's `bin/`, so on PATH in every shell): prints the banner for TOOL (`claude-code`, `opencode`; any other name is printed as given). Silent unless stdout is a tty or `NEKOSHELL_AI_WELCOME_FORCE=1`; silent when `NEKOSHELL_AI_WELCOME=0`. Colours only on a tty.
- Produces: `plugins/ai/lib.sh` with `ai_json_set FILE KEY VALUE_JSON PREVIOUS_FILE` and `ai_json_restore FILE KEY PREVIOUS_FILE` for the tool plugins (they source it as `"$NEKOSHELL_PLUGINS_DIR/ai/lib.sh"`).
- Produces: templates with `@@TOOL@@ @@PROJECT@@ @@BRANCH@@ @@COMMIT@@ @@SUBJECT@@ @@WHEN@@ @@DIR@@`; a `welcome.<tool>.txt` beside `welcome.txt` wins for that tool.

- [ ] **Step 1: Failing tests**

`tests/plugins/ai.bats` (setup as p10k.bats; also `git init -q "$HOME/repo"` with one commit `first commit` made with `git -C "$HOME/repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m "first commit"`, on a branch named `main` via `git -C "$HOME/repo" checkout -q -b main` before committing; PATH keeps the real git, so put the fakes dir AFTER `/usr/bin:/bin`... no: the `git` fake would shadow it. For this suite, export `PATH="$REPO_ROOT/tests/fakes-ai:$PATH"` where `tests/fakes-ai/` holds only `brew`, `claude` and `opencode` links to `tests/fakes/brew` and the two new fakes, so real git is used.)

```bash
@test "plugin.toml is complete and the README has its five sections" { ... }

@test "add copies the two templates once and renders the colours" {
  run "$NK" plugin add ai
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "brew install"
  [ -f "$HOME/.config/nekoshell/ai/welcome.txt" ]
  [ -f "$HOME/.config/nekoshell/ai/welcome-norepo.txt" ]
  grep -q "Mocha" "$HOME/.config/nekoshell/ai/colors.sh"
}

@test "the banner names the tool, the project, the branch and the last commit" {
  "$NK" plugin add ai >/dev/null
  cd "$HOME/repo"
  NEKOSHELL_AI_WELCOME_FORCE=1 run "$REPO_ROOT/plugins/ai/bin/nekoshell-ai-welcome" claude-code
  [ "$status" -eq 0 ]
  assert_contains "$output" "Welcome to Claude Code. You are in repo on main."
  assert_matches "$output" 'Last commit [0-9a-f]{7} "first commit" .* ago\.'
}

@test "outside a repository the banner says so" {
  "$NK" plugin add ai >/dev/null
  cd "$HOME"
  NEKOSHELL_AI_WELCOME_FORCE=1 run "$REPO_ROOT/plugins/ai/bin/nekoshell-ai-welcome" opencode
  assert_contains "$output" "Welcome to OpenCode. You are in ~, not a git repository."
}

@test "a per-tool template wins, and the shared one is used otherwise" {
  "$NK" plugin add ai >/dev/null
  echo 'Hi from @@TOOL@@ in @@PROJECT@@' > "$HOME/.config/nekoshell/ai/welcome.claude-code.txt"
  cd "$HOME/repo"
  NEKOSHELL_AI_WELCOME_FORCE=1 run "$REPO_ROOT/plugins/ai/bin/nekoshell-ai-welcome" claude-code
  [ "$output" = "Hi from Claude Code in repo" ]
  NEKOSHELL_AI_WELCOME_FORCE=1 run "$REPO_ROOT/plugins/ai/bin/nekoshell-ai-welcome" opencode
  assert_contains "$output" "Welcome to OpenCode."
}

@test "silent when stdout is not a tty, and when switched off" {
  "$NK" plugin add ai >/dev/null
  run "$REPO_ROOT/plugins/ai/bin/nekoshell-ai-welcome" claude-code
  [ -z "$output" ]
  NEKOSHELL_AI_WELCOME=0 NEKOSHELL_AI_WELCOME_FORCE=1 run "$REPO_ROOT/plugins/ai/bin/nekoshell-ai-welcome" claude-code
  [ -z "$output" ]
}

@test "nekoshell ai welcome previews, status lists the tools" {
  "$NK" plugin add ai >/dev/null
  cd "$HOME/repo"
  run "$NK" ai welcome opencode
  assert_contains "$output" "Welcome to OpenCode. You are in repo on main."
  run "$NK" ai status
  assert_contains "$output" "claude-code"
  assert_contains "$output" "not enabled"
}

@test "ai_json_set records the previous value once and restore puts it back" {
  source "$REPO_ROOT/core/lib/log.sh"; source "$REPO_ROOT/plugins/ai/lib.sh"
  echo '{"model": "opus", "theme": "dark"}' > "$HOME/s.json"
  ai_json_set "$HOME/s.json" theme '"custom:nekoshell"' "$HOME/prev.json"
  ai_json_set "$HOME/s.json" theme '"custom:nekoshell"' "$HOME/prev.json"
  [ "$(python3 -c 'import json;print(json.load(open("'"$HOME"'/s.json"))["theme"])')" = "custom:nekoshell" ]
  [ "$(python3 -c 'import json;print(json.load(open("'"$HOME"'/prev.json"))["theme"])')" = "dark" ]
  ai_json_restore "$HOME/s.json" theme "$HOME/prev.json"
  [ "$(python3 -c 'import json;print(json.load(open("'"$HOME"'/s.json"))["theme"])')" = "dark" ]
  ai_json_set "$HOME/s.json" statusLine '{"type":"command","command":"x"}' "$HOME/prev.json"
  ai_json_restore "$HOME/s.json" statusLine "$HOME/prev.json"
  python3 -c 'import json,sys;sys.exit(0 if "statusLine" not in json.load(open("'"$HOME"'/s.json")) else 1)'
}

@test "doctor reports the templates and the colours" { ... ok rows; fail when colors.sh is gone ... }
```

- [ ] **Step 2: Implementation**

`plugin.toml`: name `ai`, summary "A welcome banner for AI coding tools: which tool, which project, which branch, the last commit", `requires = []`, tags `["ai"]`.

Templates. `welcome.txt`:

```text
Welcome to @@TOOL@@. You are in @@PROJECT@@ on @@BRANCH@@.
Last commit @@COMMIT@@ "@@SUBJECT@@" @@WHEN@@.
```

`welcome-norepo.txt`:

```text
Welcome to @@TOOL@@. You are in @@DIR@@, not a git repository.
```

Both carry a leading comment? No: every line is printed. Put the placeholder list in the README and the docs page instead.

`files/colors.sh.tmpl`:

```bash
# Generated by nekoshell for the @@TITLE@@ flavour: the banner's two colours.
# Changed by `nekoshell theme <flavour>`, not by hand.
NK_AI_ACCENT=$'\033[@@sgr:mauve@@m'
NK_AI_TEXT=$'\033[@@sgr:subtext1@@m'
NK_AI_RESET=$'\033[0m'
```

`bin/nekoshell-ai-welcome`:

```bash
#!/usr/bin/env bash
# nekoshell-ai-welcome TOOL: the banner a tool plugin prints before it starts
# the tool: which tool, which project and branch, the last commit. Never
# fails a launch: every problem exits 0 quietly.
set -uo pipefail
tool="${1:-}"
[[ -n "$tool" ]] || exit 0
[[ "${NEKOSHELL_AI_WELCOME:-1}" == 0 ]] && exit 0
tty=0
[[ -t 1 ]] && tty=1
[[ "$tty" == 1 || -n "${NEKOSHELL_AI_WELCOME_FORCE:-}" ]] || exit 0

case "$tool" in
  claude-code) pretty="Claude Code" ;;
  opencode) pretty="OpenCode" ;;
  codex) pretty="Codex" ;;
  aider) pretty="Aider" ;;
  *) pretty="$tool" ;;
esac

cfg="$HOME/.config/nekoshell/ai"
NK_AI_ACCENT=""
NK_AI_TEXT=""
NK_AI_RESET=""
if [[ "$tty" == 1 && -r "$cfg/colors.sh" ]]; then
  # shellcheck source=/dev/null
  source "$cfg/colors.sh"
fi

# paint VALUE: the accent colour around a value, on a tty.
paint() { printf '%s%s%s' "$NK_AI_ACCENT" "$1" "$NK_AI_TEXT"; }

dir="${PWD/#$HOME/\~}"
if top="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  project="$(basename "$top")"
  branch="$(git branch --show-current 2>/dev/null)"
  [[ -n "$branch" ]] || branch="detached at $(git rev-parse --short HEAD 2>/dev/null || echo '?')"
  commit=""; subject=""; when=""
  IFS=$'\t' read -r commit subject when < <(git log -1 --format='%h%x09%s%x09%cr' 2>/dev/null) || true
  [[ -n "$commit" ]] || { commit="none"; subject="no commits yet"; when="ever"; }
  tmpl="$cfg/welcome.$tool.txt"
  [[ -r "$tmpl" ]] || tmpl="$cfg/welcome.txt"
  if [[ -r "$tmpl" ]]; then text="$(cat "$tmpl")"; else
    text=$'Welcome to @@TOOL@@. You are in @@PROJECT@@ on @@BRANCH@@.\nLast commit @@COMMIT@@ "@@SUBJECT@@" @@WHEN@@.'
  fi
else
  project=""; branch=""; commit=""; subject=""; when=""
  tmpl="$cfg/welcome-norepo.$tool.txt"
  [[ -r "$tmpl" ]] || tmpl="$cfg/welcome-norepo.txt"
  if [[ -r "$tmpl" ]]; then text="$(cat "$tmpl")"; else
    text='Welcome to @@TOOL@@. You are in @@DIR@@, not a git repository.'
  fi
fi

text="${text//@@TOOL@@/$(paint "$pretty")}"
text="${text//@@PROJECT@@/$(paint "$project")}"
text="${text//@@BRANCH@@/$(paint "$branch")}"
text="${text//@@COMMIT@@/$(paint "$commit")}"
text="${text//@@SUBJECT@@/$(paint "$subject")}"
text="${text//@@WHEN@@/$(paint "$when")}"
text="${text//@@DIR@@/$(paint "$dir")}"
printf '%s%s%s\n' "$NK_AI_TEXT" "$text" "$NK_AI_RESET"
exit 0
```

`lib.sh`:

```bash
#!/usr/bin/env bash
# ai plugin helpers shared with the tool plugins (they source this file).
# Both functions edit one key of a JSON file the tool owns, through python3,
# writing a temp file beside it and renaming it into place. The previous value
# is recorded in PREVIOUS_FILE the first time only, so a second run (a theme
# switch) never overwrites the user's original with our own value.
# shellcheck disable=SC2034

# ai_json_set FILE KEY VALUE_JSON PREVIOUS_FILE
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
data = load(file); old = load(prev)
if key not in old:
    old[key] = data.get(key)  # None means "was absent"
    tmp = prev + ".tmp"
    with open(tmp, "w") as f: json.dump(old, f, indent=2); f.write("\n")
    os.replace(tmp, prev)
data[key] = json.loads(value)
tmp = file + ".tmp"
with open(tmp, "w") as f: json.dump(data, f, indent=2); f.write("\n")
os.replace(tmp, file)
PY
}

# ai_json_restore FILE KEY PREVIOUS_FILE: put the recorded value back (or
# drop the key when there was none) and forget the record.
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
old = load(prev)
if key not in old: sys.exit(0)
data = load(file)
if old[key] is None: data.pop(key, None)
else: data[key] = old[key]
del old[key]
for path, obj in ((file, data), (prev, old)):
    tmp = path + ".tmp"
    with open(tmp, "w") as f: json.dump(obj, f, indent=2); f.write("\n")
    os.replace(tmp, path)
PY
}
```

`cmd/ai.sh`: `usage_ai` and `cmd_ai` with `welcome [TOOL]` (default `claude-code`; `NEKOSHELL_AI_WELCOME_FORCE=1 exec "$PLUGIN_DIR/bin/nekoshell-ai-welcome" "$tool"`), `edit` (`exec "${EDITOR:-nvim}" "$NEKOSHELL_CONFIG/ai/welcome.txt"`), `status` (for each of `claude-code opencode`: `enabled`/`not enabled`, the binary on PATH or not, whether a per-tool template exists).

`theme.sh` renders `files/colors.sh.tmpl` to `$NEKOSHELL_CONFIG/ai/colors.sh`. `doctor.sh`: `ai templates` (ok when `welcome.txt` exists), `ai colours` (flavour title in colors.sh).

README (five sections) and `docs/plugins/ai.md` with the placeholder table and `NEKOSHELL_AI_WELCOME=0`.

- [ ] **Step 3: Run, lint, commit**

```bash
git commit -m "feat(ai): a welcome banner for ai coding tools, with nekoshell ai"
```

---

### Task 2: claude-code

**Files:**

- Create: `plugins/claude-code/{plugin.toml,install.sh,plugin.zsh,theme.sh,uninstall.sh,doctor.sh,README.md}`, `plugins/claude-code/files/theme.json.tmpl`, `plugins/claude-code/files/statusline.sh.tmpl`, `docs/plugins/claude-code.md`, `tests/fakes-ai/claude`
- Test: `tests/plugins/claude-code.bats`

**Interfaces:**

- Consumes: `nekoshell-ai-welcome`, `ai_json_set`, `ai_json_restore`.
- Produces: `~/.claude/themes/nekoshell.json` (rendered), `~/.config/nekoshell/ai/claude-statusline.sh` (rendered, executable), `theme = "custom:nekoshell"` and `statusLine = {"type":"command","command":"$HOME/.config/nekoshell/ai/claude-statusline.sh"}` in `~/.claude/settings.json`, previous values in `~/.config/nekoshell/ai/claude-previous.json`.

- [ ] **Step 1: Failing tests**

Fake `claude`: `--version` prints `2.1.269 (Claude Code)`; anything else prints `claude $*`.

Tests: contract (`requires_plugins = ["ai"]`); "add enables ai first, renders the theme and the status line, and sets the two keys" (settings.json has `custom:nekoshell` and the statusline path; theme file has `"claude": "#cba6f7"` and `"base": "dark"`); "latte renders a light base" (`"base": "light"`, `#8839ef`); "an existing theme and statusLine are recorded and restored on remove"; "the claude function prints the banner on a tty and not for -p" (`script -q /dev/null zsh -ic 'cd $HOME/repo; claude; exit 0'` contains `Welcome to Claude Code` and `claude` (the fake, echoing its arguments); `zsh -ic 'claude -p hi'` output is exactly `claude -p hi`); "the status line script prints model, directory and branch from the JSON on stdin" (feed `{"model":{"display_name":"Opus"},"workspace":{"current_dir":"'$HOME/repo'"},"context_window":{"used_percentage":42}}`; output contains `Opus`, `repo`, `main`, `42%`); "doctor rows"; "install warns when claude is missing" (PATH without the fake: `install it with: brew install --cask claude-code`).

- [ ] **Step 2: Implementation**

`plugin.toml`: `requires = []`, `casks = []`, `requires_plugins = ["ai"]`, tags `["ai"]`.

`install.sh`: `command -v claude >/dev/null 2>&1 || log_warn "$PLUGIN_NAME: claude is not on PATH; install it with: brew install --cask claude-code (or https://claude.ai/install.sh)"`; `true`.

`files/theme.json.tmpl` (Claude Code custom theme; tokens from the docs' token reference):

```json
{
  "name": "nekoshell @@TITLE@@",
  "base": "@@BASE@@",
  "overrides": {
    "claude": "@@HEX:mauve@@",
    "text": "@@HEX:text@@",
    "inverseText": "@@HEX:base@@",
    "inactive": "@@HEX:overlay1@@",
    "subtle": "@@HEX:surface2@@",
    "suggestion": "@@HEX:blue@@",
    "permission": "@@HEX:lavender@@",
    "remember": "@@HEX:peach@@",
    "success": "@@HEX:green@@",
    "error": "@@HEX:red@@",
    "warning": "@@HEX:yellow@@",
    "merged": "@@HEX:mauve@@",
    "promptBorder": "@@HEX:surface2@@",
    "planMode": "@@HEX:sapphire@@",
    "autoAccept": "@@HEX:green@@",
    "bashBorder": "@@HEX:pink@@",
    "ide": "@@HEX:teal@@",
    "fastMode": "@@HEX:yellow@@",
    "selectionBg": "@@HEX:surface1@@",
    "userMessageBackground": "@@HEX:surface0@@",
    "userMessageBackgroundHover": "@@HEX:surface1@@",
    "briefLabelYou": "@@HEX:blue@@",
    "briefLabelClaude": "@@HEX:mauve@@"
  }
}
```

`theme.sh`: render to a temp path, then `sed "s/@@BASE@@/$base/"` (base is `light` for latte, `dark` otherwise) into `~/.claude/themes/nekoshell.json`; render `files/statusline.sh.tmpl` to `$NEKOSHELL_CONFIG/ai/claude-statusline.sh` and `chmod +x`; `ai_json_set "$HOME/.claude/settings.json" theme '"custom:nekoshell"' "$NEKOSHELL_CONFIG/ai/claude-previous.json"`; `ai_json_set ... statusLine "{\"type\":\"command\",\"command\":\"$NEKOSHELL_CONFIG/ai/claude-statusline.sh\"}" ...`.

`files/statusline.sh.tmpl`:

```bash
#!/usr/bin/env bash
# Generated by nekoshell for the @@TITLE@@ flavour: Claude Code's status line.
# Reads the JSON Claude Code hands it on stdin; prints model, directory,
# branch and context use in the flavour's colours.
input="$(cat)"
if command -v jq >/dev/null 2>&1; then
  IFS=$'\t' read -r model cwd pct < <(printf '%s' "$input" | jq -r '[(.model.display_name // ""), (.workspace.current_dir // .cwd // ""), ((.context_window.used_percentage // "") | tostring)] | @tsv' 2>/dev/null)
else
  IFS=$'\t' read -r model cwd pct < <(printf '%s' "$input" | python3 -c 'import json,sys
d=json.load(sys.stdin)
print("\t".join([str(d.get("model",{}).get("display_name","")), str(d.get("workspace",{}).get("current_dir", d.get("cwd",""))), str(d.get("context_window",{}).get("used_percentage",""))]))' 2>/dev/null)
fi
branch="$(git -C "${cwd:-.}" branch --show-current 2>/dev/null)"
m=$'\033[@@sgr:mauve@@m'; b=$'\033[@@sgr:blue@@m'; g=$'\033[@@sgr:green@@m'; y=$'\033[@@sgr:yellow@@m'; d=$'\033[@@sgr:overlay1@@m'; r=$'\033[0m'
out="${m}${model}${r}"
[[ -n "$cwd" ]] && out="$out ${d}·${r} ${b}${cwd##*/}${r}"
[[ -n "$branch" ]] && out="$out ${d}·${r} ${g}${branch}${r}"
[[ -n "$pct" ]] && out="$out ${d}·${r} ${y}${pct%.*}%${r}"
printf '%s\n' "$out"
```

`plugin.zsh`:

```zsh
# claude with the nekoshell banner in front of an interactive session. Any
# use that is not one (a prompt on the command line, a subcommand, a flag
# that answers and exits, no tty) runs the real binary untouched.
if (( $+commands[claude] )); then
  claude() {
    local a
    if [[ -t 1 ]]; then
      for a in "$@"; do
        case "$a" in
          -p|--print|-v|--version|-h|--help|mcp|config|plugin|update|doctor|install|auth|setup-token) command claude "$@"; return $? ;;
        esac
      done
      nekoshell-ai-welcome claude-code
    fi
    command claude "$@"
  }
fi
true
```

`uninstall.sh`: `ai_json_restore` both keys; `run rm -f` the rendered theme and statusline files. `doctor.sh`: `tool: claude` (path, or warn `not installed (brew install --cask claude-code)`), `claude theme` (rendered file names the flavour title and settings.json's `theme` is `custom:nekoshell`), `claude status line` (settings.json points at our script and it is executable).

README, docs page (with the note that Claude Code reloads `~/.claude/themes/` live but a first-ever themes directory needs one restart).

- [ ] **Step 3: Run, lint, commit**

```bash
git commit -m "feat(claude-code): catppuccin theme, status line and the banner for claude code"
```

---

### Task 3: opencode

**Files:**

- Create: `plugins/opencode/{plugin.toml,plugin.zsh,theme.sh,uninstall.sh,doctor.sh,README.md}`, `plugins/opencode/files/theme.json.tmpl`, `docs/plugins/opencode.md`, `tests/fakes-ai/opencode`
- Modify: `THIRD_PARTY.md`
- Test: `tests/plugins/opencode.bats`

**Interfaces:**

- Produces: `~/.config/opencode/themes/nekoshell.json` rendered; `"theme": "nekoshell"` in `~/.config/opencode/tui.json`, previous in `~/.config/nekoshell/ai/opencode-previous.json`.

- [ ] **Step 1: The template**

Take `packages/tui/src/theme/assets/catppuccin.json` from anomalyco/opencode (`gh api repos/anomalyco/opencode/contents/packages/tui/src/theme/assets/catppuccin.json -H 'Accept: application/vnd.github.raw'`; record the commit). Its `defs` are the Catppuccin colours under names like `darkBlue`/`lightBlue`; its `theme` maps each of the 50 keys to a def for `dark` and `light`. Write `files/theme.json.tmpl` with `"defs"` holding the 26 palette roles as `@@HEX:role@@` and each theme key set to the dark-side role name (the flavour, not a dark/light pair, decides the colours; both `dark` and `light` name the same def). Where the upstream def is a tint that is not a palette role (a diff background), use `surface0` for added/removed backgrounds and `surface1` for highlights and note it in the template's `"$schema"` neighbour comment... JSON has no comments: put the note in the README.

- [ ] **Step 2: Failing tests**

Fake `opencode`: `--version` prints `1.18.30`; else echoes `opencode $*`.

Tests: contract; "add installs opencode, renders the theme and points tui.json at it"; "latte re-renders"; "a previous theme in tui.json is recorded and restored on remove"; "the opencode function prints the banner and not for run"; "doctor rows".

- [ ] **Step 3: Implementation**

`plugin.toml`: `requires = ["opencode"]`, `requires_plugins = ["ai"]`, tags `["ai"]`. `theme.sh`: `theme_render_template` to `~/.config/opencode/themes/nekoshell.json`; `ai_json_set "$HOME/.config/opencode/tui.json" theme '"nekoshell"' "$NEKOSHELL_CONFIG/ai/opencode-previous.json"`. `plugin.zsh`: the wrapper with the skip list `run serve auth upgrade models --version -v --help -h`. `uninstall.sh` and `doctor.sh` as for claude-code. THIRD_PARTY row for the derived template.

- [ ] **Step 4: Run, lint, commit**

```bash
git commit -m "feat(opencode): catppuccin theme and the banner for opencode"
```

---

### Task 4: Docs, verification, PR

- [ ] **Step 1: Docs**: `docs/plugins/README.md` rows and the `ai` tag; `README.md`; `CHANGELOG.md`; `AGENTS.md` nothing new (ordinary plugins).

- [ ] **Step 2: This Mac**

```bash
./bin/nekoshell plugin add claude-code
./bin/nekoshell doctor --plugin ai; ./bin/nekoshell doctor --plugin claude-code
python3 -c 'import json;d=json.load(open("'"$HOME"'/.claude/settings.json"));print(d["theme"],d["statusLine"])'
brew install opencode && ./bin/nekoshell plugin add opencode && ./bin/nekoshell doctor --plugin opencode
```

Then, from a real kitty window (`env -u CLAUDECODE open -a kitty`): `cd ~/Downloads/Project/Config && claude` shows the banner and a Catppuccin-coloured Claude Code with the status line; `/theme` lists "nekoshell Mocha". `opencode` shows the banner and the theme (quit with ctrl-c). If OpenCode's theme does not apply, check `~/.config/opencode/tui.json` and its log at `~/.local/share/opencode/log/`.

- [ ] **Step 3: PR** on `feat/ai-plugins`.
