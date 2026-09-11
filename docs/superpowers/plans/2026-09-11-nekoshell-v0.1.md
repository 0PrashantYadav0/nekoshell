# nekoshell v0.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the nekoshell repo: a themed iTerm2 + zsh rig with a Pokémon/art greeting, a hotkey Spotify panel, an idempotent installer with a doctor, and docs that let a human or an AI agent install it.

**Architecture:** Plain bash scripts under `bin/` and `lib/`, config files under `stow/` symlinked into `$HOME` with GNU stow, one Python generator for the iTerm2 dynamic profile, bats-core tests that run everything against a temporary `$HOME`. No runtime beyond bash, zsh and Homebrew tools.

**Tech Stack:** bash 3.2 compatible scripts (macOS default bash), zsh 5.9, GNU stow, Homebrew Brewfile, bats-core, shellcheck, Python 3 (build scripts only), fastfetch, pokemon-colorscripts, Starship, antidote, spotify_player, shpotify, iTerm2 dynamic profiles.

**Spec:** `docs/superpowers/specs/2026-09-11-nekoshell-v0.1-spec.md`

## Global Constraints

- Repo root is the git checkout of this repo (remote `0PrashantYadav0/nekoshell`, branch `build/v0.1`). All paths below are relative to it.
- Scripts start with `#!/usr/bin/env bash` and `set -euo pipefail` (except `nekoshell-greet`, which uses `set -uo pipefail` because it must never fail a fresh shell). Must run on macOS's `/bin/bash` 3.2: no associative arrays, no `mapfile`, no `${var,,}`.
- Every `.sh` file and every file in `bin/` passes `shellcheck -x` with zero findings.
- Tests are bats-core files under `tests/`, run with `bats tests`. Every test creates a temporary `$HOME` via `tests/helpers.bash` and never touches the real home directory. Test output must be pristine.
- Theme is Catppuccin Mocha with exactly the hex values in the spec's theme table. Font name string in iTerm2 profiles is exactly `JetBrainsMonoNF-Regular 15`.
- Profile Guids are exactly `4E4B4F53-4845-4C4C-0001-000000000001` (main) and `4E4B4F53-4845-4C4C-0002-000000000002` (panel).
- Config root is `~/.config/nekoshell/`, cache root `~/.cache/nekoshell/`, backups `~/.local/share/nekoshell/backup/<UTC timestamp>/`.
- No copyrighted images in the repo. Vendored theme files (catppuccin/bat, catppuccin/btop) keep their MIT notice in `THIRD_PARTY.md`.
- Commit messages: conventional prefix (`feat:`, `test:`, `docs:`, `chore:`), and every commit ends with the two attribution lines:
  `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` and
  `Claude-Session: https://claude.ai/code/session_017Ta12tUCAdgViJZmdTMs5f`.
- Do not push. The controller pushes at the end.

---

## File structure

```
install.sh                      entry point, orchestrates lib/ steps
uninstall.sh                    restore newest backup, unstow
Brewfile                        every Homebrew formula and cask
deps.lock                       pinned git commit for pokemon-colorscripts
THIRD_PARTY.md                  licenses of vendored theme files
bin/nekoshell-greet             greeting (art + fastfetch)
bin/nekoshell-art               art pack management
bin/nekoshell-music             panel launcher (spotify_player or shpotify remote)
bin/nekoshell-doctor            health checks, --json
lib/log.sh                      info/ok/warn/fail/step printers, NEKOSHELL_DRY_RUN aware `run`
lib/paths.sh                    NEKOSHELL_ROOT, config/cache/backup paths (HOME-relative)
lib/backup.sh                   backup_path(), restore_manifest()
lib/iterm.sh                    dynamic profile generation + global prefs
lib/zsh_migrate.sh              alias migration from an old .zshrc
stow/zsh/.zshrc                 stowed to ~/.zshrc
stow/config/.config/nekoshell/zsh/{env.zsh,aliases.zsh,plugins.txt}
stow/config/.config/nekoshell/greet.conf
stow/config/.config/starship.toml
stow/config/.config/fastfetch/config.jsonc
stow/config/.config/spotify-player/{app.toml,theme.toml}
stow/config/.config/bat/{config,themes/Catppuccin Mocha.tmTheme}
stow/config/.config/btop/themes/catppuccin_mocha.theme
stow/config/.config/lazygit/config.yml
stow/config/.config/nekoshell/git/delta.gitconfig
iterm2/build-profiles.py        writes the dynamic profile JSON (two profiles)
scripts/gen-sample-art.py       pure-Python PNG writer for art/ samples
art/{neko.png,ghost.png,slime.png,README.md}
skills/nekoshell/SKILL.md
docs/{INSTALL.md,REMOTE.md,screenshots/}
AGENTS.md README.md CONTRIBUTING.md CHANGELOG.md LICENSE
tests/helpers.bash tests/*.bats
.github/workflows/check.yml
```

---

### Task 1: Repo skeleton, shared libs, test harness, CI

**Files:**
- Create: `LICENSE`, `Brewfile`, `.editorconfig`, `.github/workflows/check.yml`, `lib/log.sh`, `lib/paths.sh`, `tests/helpers.bash`, `tests/lib_log.bats`, `tests/lib_paths.bats`, `THIRD_PARTY.md` (header only)
- Modify: `.gitignore` (add `tests/tmp/`)

**Interfaces:**
- Produces: `lib/log.sh` functions `log_info MSG`, `log_ok MSG`, `log_warn MSG`, `log_fail MSG`, `log_step N TOTAL MSG`, `run CMD...` (prints and skips when `NEKOSHELL_DRY_RUN=1`, else executes), variable `NEKOSHELL_DRY_RUN`.
- Produces: `lib/paths.sh` variables `NEKOSHELL_ROOT`, `NEKOSHELL_CONFIG` (`$HOME/.config/nekoshell`), `NEKOSHELL_CACHE` (`$HOME/.cache/nekoshell`), `NEKOSHELL_DATA` (`$HOME/.local/share/nekoshell`), `NEKOSHELL_BACKUP_ROOT` (`$NEKOSHELL_DATA/backup`), `ITERM_DYNAMIC_DIR` (`$HOME/Library/Application Support/iTerm2/DynamicProfiles`), function `nekoshell_root_from SCRIPT_PATH` (realpath of the repo root given a path inside `bin/` or `lib/`).
- Produces: `tests/helpers.bash` functions `setup_tmp_home` (exports a fresh `HOME` under `tests/tmp/<random>`), `teardown_tmp_home`, variable `REPO_ROOT`.

- [ ] **Step 1: Install the dev tools**

Run: `brew install bats-core shellcheck`
Expected: both on PATH (`bats --version`, `shellcheck --version`).

- [ ] **Step 2: Write the failing tests**

`tests/helpers.bash`:
```bash
#!/usr/bin/env bash
# Shared helpers for bats tests. Every test gets a throwaway HOME.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

setup_tmp_home() {
  mkdir -p "$REPO_ROOT/tests/tmp"
  HOME="$(mktemp -d "$REPO_ROOT/tests/tmp/home.XXXXXX")"
  export HOME
  export XDG_CONFIG_HOME="$HOME/.config"
  mkdir -p "$HOME/.config" "$HOME/.cache" "$HOME/.local/share" "$HOME/.local/bin"
}

teardown_tmp_home() {
  if [[ -n "${HOME:-}" && "$HOME" == "$REPO_ROOT/tests/tmp/"* ]]; then
    rm -rf "$HOME"
  fi
}
```

`tests/lib_log.bats`:
```bash
#!/usr/bin/env bats
load helpers

setup() { setup_tmp_home; }
teardown() { teardown_tmp_home; }

@test "log_ok prints an ok line" {
  run bash -c "source '$REPO_ROOT/lib/log.sh'; log_ok 'font installed'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
  [[ "$output" == *"font installed"* ]]
}

@test "log_fail writes to stderr" {
  run bash -c "source '$REPO_ROOT/lib/log.sh'; log_fail 'missing brew' 2>&1 >/dev/null"
  [[ "$output" == *"missing brew"* ]]
}

@test "run executes the command when not in dry-run" {
  run bash -c "source '$REPO_ROOT/lib/log.sh'; run touch '$HOME/made'"
  [ "$status" -eq 0 ]
  [ -f "$HOME/made" ]
}

@test "run prints but does not execute in dry-run" {
  run bash -c "NEKOSHELL_DRY_RUN=1; export NEKOSHELL_DRY_RUN; source '$REPO_ROOT/lib/log.sh'; run touch '$HOME/made'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"touch"* ]]
  [ ! -f "$HOME/made" ]
}
```

`tests/lib_paths.bats`:
```bash
#!/usr/bin/env bats
load helpers

setup() { setup_tmp_home; }
teardown() { teardown_tmp_home; }

@test "paths derive from HOME" {
  run bash -c "source '$REPO_ROOT/lib/paths.sh'; echo \"\$NEKOSHELL_CONFIG|\$NEKOSHELL_CACHE|\$NEKOSHELL_BACKUP_ROOT\""
  [ "$output" = "$HOME/.config/nekoshell|$HOME/.cache/nekoshell|$HOME/.local/share/nekoshell/backup" ]
}

@test "nekoshell_root_from resolves the repo root from a bin path" {
  run bash -c "source '$REPO_ROOT/lib/paths.sh'; nekoshell_root_from '$REPO_ROOT/bin/anything'"
  [ "$output" = "$REPO_ROOT" ]
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `bats tests`
Expected: FAIL, `lib/log.sh: No such file or directory`.

- [ ] **Step 4: Write lib/log.sh and lib/paths.sh**

`lib/log.sh`:
```bash
#!/usr/bin/env bash
# Printing helpers shared by install.sh, uninstall.sh and bin/ scripts.
# Source this file; do not execute it.

if [[ -t 1 ]]; then
  _NK_MAUVE=$'\033[38;2;203;166;247m'
  _NK_GREEN=$'\033[38;2;166;227;161m'
  _NK_YELLOW=$'\033[38;2;249;226;175m'
  _NK_RED=$'\033[38;2;243;139;168m'
  _NK_DIM=$'\033[38;2;108;112;134m'
  _NK_RESET=$'\033[0m'
else
  _NK_MAUVE=""; _NK_GREEN=""; _NK_YELLOW=""; _NK_RED=""; _NK_DIM=""; _NK_RESET=""
fi

NEKOSHELL_DRY_RUN="${NEKOSHELL_DRY_RUN:-0}"

log_info() { printf '%s..%s %s\n' "$_NK_DIM" "$_NK_RESET" "$*"; }
log_ok()   { printf '%sok%s   %s\n' "$_NK_GREEN" "$_NK_RESET" "$*"; }
log_warn() { printf '%swarn%s %s\n' "$_NK_YELLOW" "$_NK_RESET" "$*"; }
log_fail() { printf '%sfail%s %s\n' "$_NK_RED" "$_NK_RESET" "$*" >&2; }
log_step() { printf '\n%s[%s/%s]%s %s\n' "$_NK_MAUVE" "$1" "$2" "$_NK_RESET" "$3"; }

# run CMD ARGS...: print the command, then execute it unless NEKOSHELL_DRY_RUN=1.
run() {
  printf '%s$ %s%s\n' "$_NK_DIM" "$*" "$_NK_RESET"
  if [[ "$NEKOSHELL_DRY_RUN" == "1" ]]; then
    return 0
  fi
  "$@"
}
```

`lib/paths.sh`:
```bash
#!/usr/bin/env bash
# Well-known paths. Everything is relative to $HOME so tests can redirect it.
# Source this file; do not execute it.

NEKOSHELL_CONFIG="$HOME/.config/nekoshell"
NEKOSHELL_CACHE="$HOME/.cache/nekoshell"
NEKOSHELL_DATA="$HOME/.local/share/nekoshell"
NEKOSHELL_BACKUP_ROOT="$NEKOSHELL_DATA/backup"
ITERM_DYNAMIC_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
export NEKOSHELL_CONFIG NEKOSHELL_CACHE NEKOSHELL_DATA NEKOSHELL_BACKUP_ROOT ITERM_DYNAMIC_DIR

# nekoshell_root_from PATH: given a path to a file inside bin/ or lib/, print the repo root.
nekoshell_root_from() {
  local p="$1" dir
  dir="$(cd "$(dirname "$p")" && pwd -P)"
  (cd "$dir/.." && pwd -P)
}

# NEKOSHELL_ROOT: the checkout. Prefer the recorded root, else derive from this file.
if [[ -z "${NEKOSHELL_ROOT:-}" ]]; then
  if [[ -r "$NEKOSHELL_CONFIG/root" ]]; then
    NEKOSHELL_ROOT="$(cat "$NEKOSHELL_CONFIG/root")"
  else
    NEKOSHELL_ROOT="$(nekoshell_root_from "${BASH_SOURCE[0]}")"
  fi
fi
export NEKOSHELL_ROOT
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bats tests`
Expected: 6 tests, all pass.

- [ ] **Step 6: Add LICENSE, Brewfile, .editorconfig, THIRD_PARTY.md, CI**

`LICENSE`: the MIT License text with `Copyright (c) 2026 Prashant Kumar Yadav`.

`Brewfile`:
```ruby
tap "homebrew/bundle"
cask "font-jetbrains-mono-nerd-font"
cask "iterm2"
brew "antidote"
brew "bat"
brew "bats-core"
brew "btop"
brew "eza"
brew "fastfetch"
brew "fd"
brew "fzf"
brew "git-delta"
brew "lazygit"
brew "ripgrep"
brew "shellcheck"
brew "shpotify"
brew "spotify_player"
brew "starship"
brew "stow"
brew "zoxide"
```

`.editorconfig`:
```ini
root = true
[*]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true
```

`THIRD_PARTY.md`:
```markdown
# Third-party files

Files vendored into this repo and their licenses. Everything else is MIT (see LICENSE).

| Path | Source | License |
|---|---|---|
```

`.github/workflows/check.yml`:
```yaml
name: check
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - run: brew install bats-core shellcheck
      - run: shellcheck -x install.sh uninstall.sh lib/*.sh bin/* 2>/dev/null || shellcheck -x lib/*.sh
      - run: bats tests
```

Append `tests/tmp/` to `.gitignore`.

- [ ] **Step 7: Run shellcheck and the tests**

Run: `shellcheck -x lib/*.sh tests/helpers.bash && bats tests`
Expected: no shellcheck output, 6 tests pass.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "chore: repo skeleton, shared libs, bats harness, CI"
```

---

### Task 2: iTerm2 profile generator and global prefs

**Files:**
- Create: `iterm2/build-profiles.py`, `lib/iterm.sh`, `tests/iterm_profiles.bats`

**Interfaces:**
- Consumes: `lib/log.sh` (`run`, `log_*`), `lib/paths.sh` (`ITERM_DYNAMIC_DIR`, `NEKOSHELL_ROOT`).
- Produces: `iterm2/build-profiles.py --root ROOT --out FILE [--window-type N]` writes the dynamic profile JSON. `lib/iterm.sh` functions `iterm_write_profiles` (calls the generator with `NEKOSHELL_ROOT` into `ITERM_DYNAMIC_DIR/nekoshell.json`), `iterm_is_running` (exit 0 if `pgrep -xq iTerm2`), `iterm_apply_prefs` (the `defaults write` calls), `iterm_prefs_pending` (exit 0 if the default Guid pref is not the main Guid).
- Constants: `NEKOSHELL_MAIN_GUID=4E4B4F53-4845-4C4C-0001-000000000001`, `NEKOSHELL_PANEL_GUID=4E4B4F53-4845-4C4C-0002-000000000002`, `NEKOSHELL_PANEL_WINDOW_TYPE=6` (overridable by env; Task 8 verifies the real value).

- [ ] **Step 1: Write the failing test**

`tests/iterm_profiles.bats`:
```bash
#!/usr/bin/env bats
load helpers

setup() { setup_tmp_home; OUT="$HOME/nekoshell.json"; }
teardown() { teardown_tmp_home; }

@test "generator writes two profiles with fixed guids" {
  run python3 "$REPO_ROOT/iterm2/build-profiles.py" --root "$REPO_ROOT" --out "$OUT"
  [ "$status" -eq 0 ]
  run python3 -c "import json,sys; d=json.load(open('$OUT')); print(len(d['Profiles'])); print(d['Profiles'][0]['Guid']); print(d['Profiles'][1]['Guid'])"
  [ "${lines[0]}" = "2" ]
  [ "${lines[1]}" = "4E4B4F53-4845-4C4C-0001-000000000001" ]
  [ "${lines[2]}" = "4E4B4F53-4845-4C4C-0002-000000000002" ]
}

@test "main profile carries the theme, font and window settings" {
  python3 "$REPO_ROOT/iterm2/build-profiles.py" --root "$REPO_ROOT" --out "$OUT"
  run python3 - "$OUT" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))['Profiles'][0]
bg=p['Background Color']
print(p['Name'], p['Normal Font'], p['ASCII Ligatures'], p['Window Type'], p['Transparency'], p['Blur'], p['Blur Radius'])
print(round(bg['Red Component']*255), round(bg['Green Component']*255), round(bg['Blue Component']*255), bg['Color Space'])
print(round(p['Ansi 5 Color']['Red Component']*255), round(p['Ansi 5 Color']['Green Component']*255), round(p['Ansi 5 Color']['Blue Component']*255))
PY
  [ "${lines[0]}" = "nekoshell JetBrainsMonoNF-Regular 15 True 0 0.1 True 24" ]
  [ "${lines[1]}" = "30 30 46 sRGB" ]
  [ "${lines[2]}" = "245 194 231" ]
}

@test "panel profile is a right-docked hotkey window running nekoshell-music" {
  python3 "$REPO_ROOT/iterm2/build-profiles.py" --root "$REPO_ROOT" --out "$OUT" --window-type 6
  run python3 - "$OUT" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))['Profiles'][1]
print(p['Name'], p['Has Hotkey'], p['HotKey Key Code'], p['HotKey Characters'], p['HotKey Characters Ignoring Modifiers'], p['HotKey Modifier Flags'])
print(p['HotKey Window Animates'], p['HotKey Window AutoHides'], p['HotKey Window Floats'], p['HotKey Window Reopens On Activation'], p['Window Type'], p['Space'], p['Columns'], p['Rows'])
print(p['Custom Command'], p['Command'])
PY
  [ "${lines[0]}" = "nekoshell panel True 46 µ m 524288" ]
  [ "${lines[1]}" = "True True True False 6 -1 60 40" ]
  [ "${lines[2]}" = "Yes /usr/bin/env NEKOSHELL_PANEL=1 $REPO_ROOT/bin/nekoshell-music" ]
}

@test "iterm_write_profiles writes into the DynamicProfiles dir" {
  run bash -c "source '$REPO_ROOT/lib/log.sh'; source '$REPO_ROOT/lib/paths.sh'; NEKOSHELL_ROOT='$REPO_ROOT'; source '$REPO_ROOT/lib/iterm.sh'; iterm_write_profiles"
  [ "$status" -eq 0 ]
  [ -f "$HOME/Library/Application Support/iTerm2/DynamicProfiles/nekoshell.json" ]
}

@test "iterm_apply_prefs in dry-run prints the defaults commands without running them" {
  run bash -c "NEKOSHELL_DRY_RUN=1; export NEKOSHELL_DRY_RUN; source '$REPO_ROOT/lib/log.sh'; source '$REPO_ROOT/lib/paths.sh'; source '$REPO_ROOT/lib/iterm.sh'; iterm_apply_prefs"
  [ "$status" -eq 0 ]
  [[ "$output" == *"defaults write com.googlecode.iterm2 Default Bookmark Guid -string 4E4B4F53-4845-4C4C-0001-000000000001"* ]]
  [[ "$output" == *"HideTab -bool true"* ]]
  [[ "$output" == *"TerminalMargin -int 16"* ]]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/iterm_profiles.bats`
Expected: FAIL, `build-profiles.py: No such file or directory`.

- [ ] **Step 3: Write iterm2/build-profiles.py**

```python
#!/usr/bin/env python3
"""Write the nekoshell iTerm2 dynamic profile file (main profile + Spotify panel).

Usage: build-profiles.py --root /path/to/checkout --out FILE [--window-type N]
"""
import argparse
import json

MAIN_GUID = "4E4B4F53-4845-4C4C-0001-000000000001"
PANEL_GUID = "4E4B4F53-4845-4C4C-0002-000000000002"
FONT = "JetBrainsMonoNF-Regular 15"

MOCHA = {
    "base": "1e1e2e", "mantle": "181825", "crust": "11111b",
    "surface0": "313244", "surface1": "45475a", "surface2": "585b70",
    "overlay0": "6c7086", "subtext0": "a6adc8", "subtext1": "bac2de",
    "text": "cdd6f4", "rosewater": "f5e0dc", "pink": "f5c2e7", "mauve": "cba6f7",
    "red": "f38ba8", "peach": "fab387", "yellow": "f9e2af", "green": "a6e3a1",
    "teal": "94e2d5", "sky": "89dceb", "blue": "89b4fa", "lavender": "b4befe",
}

ANSI = ["surface1", "red", "green", "yellow", "blue", "pink", "teal", "subtext1",
        "surface2", "red", "green", "yellow", "blue", "pink", "teal", "subtext0"]


def color(name):
    h = MOCHA[name]
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return {"Red Component": r, "Green Component": g, "Blue Component": b,
            "Alpha Component": 1, "Color Space": "sRGB"}


def base_profile(name, guid):
    p = {
        "Name": name,
        "Guid": guid,
        "Tags": ["nekoshell"],
        "Normal Font": FONT,
        "ASCII Ligatures": True,
        "Use Non-ASCII Font": False,
        "Use Bold Font": True,
        "Use Bright Bold": True,
        "Minimum Contrast": 0,
        "Cursor Type": 1,
        "Blinking Cursor": False,
        "Unlimited Scrollback": True,
        "Silence Bell": True,
        "Show Status Bar": False,
        "Blur": True,
        "Blur Radius": 24,
        "Transparency": 0.1,
        "Initial Use Transparency": True,
        "Window Type": 0,
        "Foreground Color": color("text"),
        "Background Color": color("base"),
        "Bold Color": color("text"),
        "Cursor Color": color("rosewater"),
        "Cursor Text Color": color("base"),
        "Cursor Guide Color": color("surface0"),
        "Selection Color": color("surface2"),
        "Selected Text Color": color("text"),
        "Link Color": color("blue"),
        "Badge Color": color("peach"),
        "Use Tab Color": True,
        "Tab Color": color("mauve"),
    }
    for i, role in enumerate(ANSI):
        p[f"Ansi {i} Color"] = color(role)
    return p


def panel_profile(root, window_type):
    p = base_profile("nekoshell panel", PANEL_GUID)
    p.update({
        "Transparency": 0.06,
        "Has Hotkey": True,
        "HotKey Key Code": 46,
        "HotKey Characters": "µ",
        "HotKey Characters Ignoring Modifiers": "m",
        "HotKey Modifier Flags": 524288,
        "HotKey Window Animates": True,
        "HotKey Window AutoHides": True,
        "HotKey Window Floats": True,
        "HotKey Window Reopens On Activation": False,
        "HotKey Window Dock Click Action": 0,
        "Window Type": window_type,
        "Space": -1,
        "Screen": -2,
        "Columns": 60,
        "Rows": 40,
        "Custom Command": "Yes",
        "Command": f"/usr/bin/env NEKOSHELL_PANEL=1 {root}/bin/nekoshell-music",
    })
    return p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--window-type", type=int, default=6,
                    help="iTerm2 numeric window type for 'Right of screen'")
    a = ap.parse_args()
    doc = {"Profiles": [base_profile("nekoshell", MAIN_GUID), panel_profile(a.root, a.window_type)]}
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2, ensure_ascii=False)
        f.write("\n")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Write lib/iterm.sh**

```bash
#!/usr/bin/env bash
# iTerm2 integration: dynamic profile file and global preferences.
# Requires lib/log.sh and lib/paths.sh to be sourced first.

NEKOSHELL_MAIN_GUID="4E4B4F53-4845-4C4C-0001-000000000001"
NEKOSHELL_PANEL_GUID="4E4B4F53-4845-4C4C-0002-000000000002"
NEKOSHELL_PANEL_WINDOW_TYPE="${NEKOSHELL_PANEL_WINDOW_TYPE:-6}"
export NEKOSHELL_MAIN_GUID NEKOSHELL_PANEL_GUID NEKOSHELL_PANEL_WINDOW_TYPE

iterm_is_running() { pgrep -xq iTerm2; }

# Generate ~/Library/Application Support/iTerm2/DynamicProfiles/nekoshell.json.
iterm_write_profiles() {
  run mkdir -p "$ITERM_DYNAMIC_DIR"
  run python3 "$NEKOSHELL_ROOT/iterm2/build-profiles.py" \
    --root "$NEKOSHELL_ROOT" \
    --out "$ITERM_DYNAMIC_DIR/nekoshell.json" \
    --window-type "$NEKOSHELL_PANEL_WINDOW_TYPE"
}

# Global prefs. Only meaningful when iTerm2 is not running (it rewrites the plist on quit).
iterm_apply_prefs() {
  run defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "$NEKOSHELL_MAIN_GUID"
  run defaults write com.googlecode.iterm2 HideTab -bool true
  run defaults write com.googlecode.iterm2 TerminalMargin -int 16
  run defaults write com.googlecode.iterm2 TerminalVMargin -int 12
  run defaults write com.googlecode.iterm2 PromptOnQuit -bool false
  run defaults write com.googlecode.iterm2 HideScrollbar -bool true
}

# Exit 0 when the global prefs have not been applied yet.
iterm_prefs_pending() {
  local current
  current="$(defaults read com.googlecode.iterm2 "Default Bookmark Guid" 2>/dev/null || true)"
  [[ "$current" != "$NEKOSHELL_MAIN_GUID" ]]
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bats tests/iterm_profiles.bats && shellcheck -x lib/iterm.sh`
Expected: 5 tests pass, no shellcheck output.

- [ ] **Step 6: Commit**

```bash
git add iterm2/build-profiles.py lib/iterm.sh tests/iterm_profiles.bats
git commit -m "feat: iTerm2 dynamic profile generator and global prefs"
```

---

### Task 3: Shell stack: zshrc, Starship, antidote plugins, themed tool configs

**Files:**
- Create: `stow/zsh/.zshrc`, `stow/config/.config/nekoshell/zsh/env.zsh`, `stow/config/.config/nekoshell/zsh/aliases.zsh`, `stow/config/.config/nekoshell/zsh/plugins.txt`, `stow/config/.config/starship.toml`, `stow/config/.config/bat/config`, `stow/config/.config/bat/themes/Catppuccin Mocha.tmTheme`, `stow/config/.config/btop/themes/catppuccin_mocha.theme`, `stow/config/.config/lazygit/config.yml`, `stow/config/.config/nekoshell/git/delta.gitconfig`, `lib/zsh_migrate.sh`, `tests/zsh_stack.bats`
- Modify: `THIRD_PARTY.md` (two rows)

**Interfaces:**
- Consumes: nothing from earlier tasks except `tests/helpers.bash`.
- Produces: `lib/zsh_migrate.sh` function `zsh_migrate_aliases OLD_ZSHRC DEST` (writes `alias ` and `export ` lines that are not oh-my-zsh/p10k related into DEST if DEST does not exist; prints the count).
- Produces: `~/.zshrc` behaviour: exports `NEKOSHELL_ROOT`, prepends `$NEKOSHELL_ROOT/bin:$HOME/.local/bin` to PATH, sources env.zsh, aliases.zsh, local.zsh (if present), loads antidote, inits zoxide/fzf/starship when present, runs `nekoshell-greet` if interactive.

- [ ] **Step 1: Write the failing tests**

`tests/zsh_stack.bats`:
```bash
#!/usr/bin/env bats
load helpers

setup() { setup_tmp_home; }
teardown() { teardown_tmp_home; }

stow_it() {
  stow -d "$REPO_ROOT/stow" -t "$HOME" zsh config
}

@test "zshrc parses and sets NEKOSHELL_ROOT and PATH from its stowed location" {
  stow_it
  run zsh -c 'source "$HOME/.zshrc"; echo "$NEKOSHELL_ROOT"; echo "$PATH"' 
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$REPO_ROOT" ]
  [[ "${lines[1]}" == "$REPO_ROOT/bin:$HOME/.local/bin:"* ]]
}

@test "zshrc sources local.zsh when present" {
  stow_it
  mkdir -p "$HOME/.config/nekoshell/zsh"
  echo 'export NEKO_LOCAL_MARK=yes' > "$HOME/.config/nekoshell/zsh/local.zsh"
  run zsh -c 'source "$HOME/.zshrc"; echo "$NEKO_LOCAL_MARK"'
  [ "$output" = "yes" ]
}

@test "non-interactive zsh does not greet" {
  stow_it
  run zsh -c 'source "$HOME/.zshrc"; echo done'
  [ "$output" = "done" ]
}

@test "starship config is valid TOML with the mocha palette" {
  run python3 -c "
import tomllib,sys
d=tomllib.load(open('$REPO_ROOT/stow/config/.config/starship.toml','rb'))
print(d['palette']); print(d['palettes']['catppuccin_mocha']['mauve'])"
  [ "${lines[0]}" = "catppuccin_mocha" ]
  [ "${lines[1]}" = "#cba6f7" ]
}

@test "zsh_migrate_aliases copies plain aliases and exports only" {
  cat > "$HOME/old.zshrc" <<'EOF'
export ZSH="$HOME/.oh-my-zsh"
plugins=(git)
alias gs='git status'
export EDITOR=vim
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
alias ohmyzsh="mate ~/.oh-my-zsh"
EOF
  run bash -c "source '$REPO_ROOT/lib/zsh_migrate.sh'; zsh_migrate_aliases '$HOME/old.zshrc' '$HOME/local.zsh'"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
  run cat "$HOME/local.zsh"
  [[ "$output" == *"alias gs='git status'"* ]]
  [[ "$output" == *"export EDITOR=vim"* ]]
  [[ "$output" != *"oh-my-zsh"* ]]
}

@test "zsh_migrate_aliases does not overwrite an existing destination" {
  echo 'alias keep=1' > "$HOME/local.zsh"
  echo "alias gs='git status'" > "$HOME/old.zshrc"
  run bash -c "source '$REPO_ROOT/lib/zsh_migrate.sh'; zsh_migrate_aliases '$HOME/old.zshrc' '$HOME/local.zsh'"
  [ "$output" = "0" ]
  run cat "$HOME/local.zsh"
  [ "$output" = "alias keep=1" ]
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bats tests/zsh_stack.bats`
Expected: FAIL (stow package `zsh` does not exist).

- [ ] **Step 3: Write the stow files**

`stow/zsh/.zshrc`:
```zsh
# nekoshell zshrc. Managed by https://github.com/0PrashantYadav0/nekoshell
# Put your own additions in ~/.config/nekoshell/zsh/local.zsh (never overwritten).

# Locate the checkout from this file's real path: stow/zsh/.zshrc -> repo root.
NEKOSHELL_ROOT="${${(%):-%x}:A:h:h:h}"
export NEKOSHELL_ROOT
export PATH="$NEKOSHELL_ROOT/bin:$HOME/.local/bin:$PATH"

NEKOSHELL_CONFIG="$HOME/.config/nekoshell"

[[ -r "$NEKOSHELL_CONFIG/zsh/env.zsh" ]] && source "$NEKOSHELL_CONFIG/zsh/env.zsh"
[[ -r "$NEKOSHELL_CONFIG/zsh/aliases.zsh" ]] && source "$NEKOSHELL_CONFIG/zsh/aliases.zsh"
[[ -r "$NEKOSHELL_CONFIG/zsh/local.zsh" ]] && source "$NEKOSHELL_CONFIG/zsh/local.zsh"

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS SHARE_HISTORY HIST_IGNORE_SPACE

# Completion
autoload -Uz compinit && compinit -C
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# Plugins via antidote (Homebrew)
if [[ -r "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/antidote/share/antidote/antidote.zsh" ]]; then
  source "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/antidote/share/antidote/antidote.zsh"
  antidote load "$NEKOSHELL_CONFIG/zsh/plugins.txt"
fi

# Tools
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
(( $+commands[fzf] )) && source <(fzf --zsh)
(( $+commands[starship] )) && eval "$(starship init zsh)"

# Greeting: only for interactive shells that own a terminal.
if [[ -o interactive ]] && (( $+commands[nekoshell-greet] )); then
  nekoshell-greet
fi
```

`stow/config/.config/nekoshell/zsh/env.zsh`:
```zsh
# Environment shared by every nekoshell shell.
export EDITOR="${EDITOR:-nvim}"
export BAT_THEME="Catppuccin Mocha"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--color=selected-bg:#45475a --multi --height=40% --layout=reverse --border=rounded"
export EZA_COLORS="da=38;5;245:di=1;34:ex=1;32:ln=36:ur=33:uw=31:ux=32:gr=33:gw=31:gx=32:tr=33:tw=31:tx=32"
export LESS="-R"
```

`stow/config/.config/nekoshell/zsh/aliases.zsh`:
```zsh
# Aliases. eza/bat replace ls/cat only when installed.
if (( $+commands[eza] )); then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza --icons --group-directories-first -l --git'
  alias la='eza --icons --group-directories-first -la --git'
  alias lt='eza --icons --tree --level=2'
fi
(( $+commands[bat] )) && alias cat='bat --paging=never'
(( $+commands[lazygit] )) && alias lg='lazygit'
(( $+commands[btop] )) && alias top='btop'
alias greet='nekoshell-greet'
alias music='nekoshell-music'
alias doctor='nekoshell-doctor'
alias g='git'
alias ..='cd ..'
alias ...='cd ../..'
```

`stow/config/.config/nekoshell/zsh/plugins.txt`:
```
zsh-users/zsh-completions
Aloxaf/fzf-tab
zsh-users/zsh-autosuggestions
zsh-users/zsh-syntax-highlighting
```

`stow/config/.config/starship.toml`:
```toml
"$schema" = 'https://starship.rs/config-schema.json'
add_newline = true
palette = "catppuccin_mocha"

format = """
$directory$git_branch$git_status$nodejs$python$rust$golang
$character"""
right_format = "$cmd_duration"

[palettes.catppuccin_mocha]
rosewater = "#f5e0dc"
pink = "#f5c2e7"
mauve = "#cba6f7"
red = "#f38ba8"
peach = "#fab387"
yellow = "#f9e2af"
green = "#a6e3a1"
teal = "#94e2d5"
blue = "#89b4fa"
lavender = "#b4befe"
text = "#cdd6f4"
subtext0 = "#a6adc8"
overlay0 = "#6c7086"
surface0 = "#313244"
base = "#1e1e2e"

[directory]
style = "bold blue"
truncation_length = 3
truncate_to_repo = true
format = "[$path]($style)[$read_only]($read_only_style) "

[git_branch]
symbol = " "
style = "mauve"
format = "[$symbol$branch]($style) "

[git_status]
style = "red"
format = "[$all_status$ahead_behind]($style) "

[cmd_duration]
min_time = 2000
style = "yellow"
format = "[$duration]($style)"

[character]
success_symbol = "[❯](pink)"
error_symbol = "[❯](red)"
vimcmd_symbol = "[❮](green)"

[nodejs]
symbol = " "
style = "green"
format = "[$symbol$version]($style) "

[python]
symbol = " "
style = "yellow"
format = "[$symbol$version]($style) "

[rust]
symbol = " "
style = "peach"
format = "[$symbol$version]($style) "

[golang]
symbol = " "
style = "teal"
format = "[$symbol$version]($style) "
```

`stow/config/.config/bat/config`:
```
--theme="Catppuccin Mocha"
--style=numbers,changes,header
```

`stow/config/.config/bat/themes/Catppuccin Mocha.tmTheme`: download from `https://raw.githubusercontent.com/catppuccin/bat/main/themes/Catppuccin%20Mocha.tmTheme` (MIT). Record the commit you fetched in `THIRD_PARTY.md`.

`stow/config/.config/btop/themes/catppuccin_mocha.theme`: download from `https://raw.githubusercontent.com/catppuccin/btop/main/themes/catppuccin_mocha.theme` (MIT). Record it in `THIRD_PARTY.md`.

`stow/config/.config/lazygit/config.yml`:
```yaml
gui:
  theme:
    activeBorderColor: ["#cba6f7", bold]
    inactiveBorderColor: ["#a6adc8"]
    optionsTextColor: ["#89b4fa"]
    selectedLineBgColor: ["#313244"]
    cherryPickedCommitBgColor: ["#45475a"]
    cherryPickedCommitFgColor: ["#cba6f7"]
    unstagedChangesColor: ["#f38ba8"]
    defaultFgColor: ["#cdd6f4"]
    searchingActiveBorderColor: ["#f9e2af"]
  nerdFontsVersion: "3"
git:
  paging:
    colorArg: always
    pager: delta --dark --paging=never
```

`stow/config/.config/nekoshell/git/delta.gitconfig`:
```ini
# Included from ~/.gitconfig by the nekoshell installer.
[core]
	pager = delta
[interactive]
	diffFilter = delta --color-only
[delta]
	navigate = true
	line-numbers = true
	syntax-theme = Catppuccin Mocha
	side-by-side = false
[merge]
	conflictstyle = zdiff3
```

- [ ] **Step 4: Write lib/zsh_migrate.sh**

```bash
#!/usr/bin/env bash
# Copy a user's plain aliases and exports out of their old .zshrc.
# Source this file; do not execute it.

# zsh_migrate_aliases OLD_ZSHRC DEST: write matching lines to DEST unless DEST exists.
# Prints the number of lines written.
zsh_migrate_aliases() {
  local old="$1" dest="$2" count=0 line
  if [[ -e "$dest" || ! -r "$old" ]]; then
    echo 0
    return 0
  fi
  {
    echo "# Migrated from your previous .zshrc by nekoshell on $(date -u +%Y-%m-%dT%H:%M:%SZ)."
    echo "# Edit freely; nekoshell never overwrites this file."
    while IFS= read -r line; do
      case "$line" in
        alias\ *|export\ *)
          case "$line" in
            *oh-my-zsh*|*ZSH=*|*p10k*|*POWERLEVEL*) continue ;;
          esac
          printf '%s\n' "$line"
          count=$((count + 1))
          ;;
      esac
    done < "$old"
  } > "$dest"
  echo "$count"
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bats tests/zsh_stack.bats && shellcheck -x lib/zsh_migrate.sh && zsh -n stow/zsh/.zshrc`
Expected: 6 tests pass, no shellcheck or zsh output. Note: python 3.11+ is required for `tomllib`; Homebrew python3 on this machine is 3.14.

- [ ] **Step 6: Commit**

```bash
git add stow lib/zsh_migrate.sh tests/zsh_stack.bats THIRD_PARTY.md
git commit -m "feat: zsh, starship, antidote and themed tool configs"
```

---

### Task 4: Greeting: fastfetch config, art pack, nekoshell-greet, nekoshell-art

**Files:**
- Create: `bin/nekoshell-greet`, `bin/nekoshell-art`, `stow/config/.config/fastfetch/config.jsonc`, `stow/config/.config/nekoshell/greet.conf`, `scripts/gen-sample-art.py`, `art/README.md`, `art/neko.png`, `art/ghost.png`, `art/slime.png`, `tests/greet.bats`, `tests/fakes/pokemon-colorscripts`, `tests/fakes/fastfetch`

**Interfaces:**
- Consumes: `lib/paths.sh` (`NEKOSHELL_CONFIG`, `NEKOSHELL_CACHE`).
- Produces: `nekoshell-greet` behaviour per spec; `nekoshell-art add|list|sample`; cache file `$NEKOSHELL_CACHE/art-name`.
- Test fakes: `tests/fakes/pokemon-colorscripts` prints `pikachu` (or `pikachu (shiny)` with `-s`) then three sprite lines; `tests/fakes/fastfetch` prints its arguments as one line and, when `--file-raw -` is present, echoes stdin line count as `stdin=N`.

- [ ] **Step 1: Write the fakes and the failing tests**

`tests/fakes/pokemon-colorscripts`:
```bash
#!/usr/bin/env bash
name="pikachu"
for a in "$@"; do [[ "$a" == "-s" ]] && name="pikachu (shiny)"; done
echo "$name"
printf '▄▄▄\n███\n▀▀▀\n'
```

`tests/fakes/fastfetch`:
```bash
#!/usr/bin/env bash
args="$*"
if [[ "$args" == *"--file-raw -"* ]]; then
  n=$(wc -l < /dev/stdin | tr -d ' ')
  echo "fastfetch $args stdin=$n"
else
  echo "fastfetch $args"
fi
```

Both `chmod +x`.

`tests/greet.bats`:
```bash
#!/usr/bin/env bats
load helpers

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export TERM_PROGRAM="iTerm.app"
  unset CLAUDECODE TMUX NEKOSHELL_PANEL SSH_CONNECTION NEKOSHELL_NO_GREET NEKOSHELL_GREET_SSH
  mkdir -p "$HOME/.config/nekoshell/art" "$HOME/.config/fastfetch"
  cp "$REPO_ROOT/stow/config/.config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/"
}
teardown() { teardown_tmp_home; }

greet() { script -q /dev/null "$REPO_ROOT/bin/nekoshell-greet" "$@" < /dev/null; }

@test "silent when CLAUDECODE is set" {
  CLAUDECODE=1 run greet
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "silent inside tmux and inside the panel" {
  TMUX=/tmp/x run greet; [ -z "$output" ]
  NEKOSHELL_PANEL=1 run greet; [ -z "$output" ]
}

@test "silent over ssh unless opted in" {
  SSH_CONNECTION="1 2 3 4" run greet; [ -z "$output" ]
  SSH_CONNECTION="1 2 3 4" NEKOSHELL_GREET_SSH=1 NEKOSHELL_SEED=1 run greet
  [[ "$output" == *"fastfetch"* ]]
}

@test "silent when stdout is not a tty" {
  run "$REPO_ROOT/bin/nekoshell-greet"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "pokemon path pipes the sprite into fastfetch and caches the name" {
  NEKOSHELL_SEED=1 run greet
  [ "$status" -eq 0 ]
  [[ "$output" == *"--file-raw - stdin=3"* ]]
  [ "$(cat "$HOME/.cache/nekoshell/art-name")" = "pikachu" ]
}

@test "image path is used when the roll lands above the pokemon share" {
  cp "$REPO_ROOT/art/neko.png" "$HOME/.config/nekoshell/art/"
  echo 'POKEMON_SHARE=0' > "$HOME/.config/nekoshell/greet.conf"
  NEKOSHELL_SEED=1 run greet
  [[ "$output" == *"--iterm $HOME/.config/nekoshell/art/neko.png --logo-width 28 --logo-height 14"* ]]
  [ "$(cat "$HOME/.cache/nekoshell/art-name")" = "neko.png" ]
}

@test "falls back to pokemon when the art pack is empty" {
  echo 'POKEMON_SHARE=0' > "$HOME/.config/nekoshell/greet.conf"
  NEKOSHELL_SEED=1 run greet
  [[ "$output" == *"--file-raw -"* ]]
}

@test "falls back to pokemon outside iTerm2" {
  cp "$REPO_ROOT/art/neko.png" "$HOME/.config/nekoshell/art/"
  echo 'POKEMON_SHARE=0' > "$HOME/.config/nekoshell/greet.conf"
  TERM_PROGRAM=Apple_Terminal NEKOSHELL_SEED=1 run greet
  [[ "$output" == *"--file-raw -"* ]]
}

@test "shiny odds of 1 always passes -s" {
  echo 'SHINY_ODDS=1' > "$HOME/.config/nekoshell/greet.conf"
  NEKOSHELL_SEED=1 run greet
  [ "$(cat "$HOME/.cache/nekoshell/art-name")" = "pikachu (shiny) ✦ shiny" ]
}

@test "prints nothing when fastfetch is missing" {
  PATH="$REPO_ROOT/tests/tmp/nothing:/usr/bin:/bin" NEKOSHELL_SEED=1 run greet
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "NEKOSHELL_GREET_TIME prints a millisecond line" {
  NEKOSHELL_GREET_TIME=1 NEKOSHELL_SEED=1 run greet
  [[ "${lines[-1]}" =~ ^greet:\ [0-9]+\ ms$ ]]
}

@test "nekoshell-art list and add" {
  run "$REPO_ROOT/bin/nekoshell-art" list
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run "$REPO_ROOT/bin/nekoshell-art" add "$REPO_ROOT/art/ghost.png"
  [ "$status" -eq 0 ]
  run "$REPO_ROOT/bin/nekoshell-art" list
  [ "$output" = "ghost.png" ]
}

@test "sample art files are valid PNGs" {
  for f in neko ghost slime; do
    run python3 -c "d=open('$REPO_ROOT/art/$f.png','rb').read(8); print(d==b'\x89PNG\r\n\x1a\n')"
    [ "$output" = "True" ]
  done
}
```

Note on `greet()`: `script -q /dev/null CMD` gives the command a pseudo-TTY on macOS so the `-t 1` guard passes. The fake fastfetch's `--iterm` line must be matched as a substring because `script` may append a carriage return.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bats tests/greet.bats`
Expected: FAIL, `bin/nekoshell-greet: No such file`.

- [ ] **Step 3: Write the fastfetch config and greet.conf**

`stow/config/.config/fastfetch/config.jsonc`:
```jsonc
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  // The logo is passed on the command line by nekoshell-greet.
  "display": {
    "separator": "  ",
    "color": { "keys": "magenta", "title": "blue" }
  },
  "modules": [
    "title",
    "separator",
    { "type": "os", "key": "OS" },
    { "type": "host", "key": "Host" },
    { "type": "kernel", "key": "Kernel" },
    { "type": "uptime", "key": "Uptime" },
    { "type": "shell", "key": "Shell" },
    { "type": "terminal", "key": "Terminal" },
    { "type": "terminalfont", "key": "Font" },
    { "type": "cpu", "key": "CPU" },
    { "type": "memory", "key": "Memory" },
    { "type": "packages", "key": "Packages" },
    { "type": "command", "key": "Art", "text": "cat \"$HOME/.cache/nekoshell/art-name\" 2>/dev/null" },
    "break",
    "colors"
  ]
}
```

`stow/config/.config/nekoshell/greet.conf`:
```bash
# nekoshell greeting settings (sourced by bash; keep KEY=VALUE).
POKEMON_SHARE=70   # percent of launches that show a Pokémon; the rest use your art pack
SHINY_ODDS=128     # 1 in N Pokémon are shiny
GENERATIONS=""     # e.g. "1-3" or "1,4"; empty means all
IMAGE_WIDTH=28     # art pack image size in terminal cells
IMAGE_HEIGHT=14
```

- [ ] **Step 4: Write bin/nekoshell-greet**

```bash
#!/usr/bin/env bash
# nekoshell-greet: art + machine stats for a new interactive terminal.
# Never fails a fresh shell: every problem exits 0 quietly.
set -uo pipefail

[[ -t 1 ]] || exit 0
[[ -n "${NEKOSHELL_NO_GREET:-}" ]] && exit 0
[[ -n "${CLAUDECODE:-}" ]] && exit 0
[[ -n "${TMUX:-}" ]] && exit 0
[[ -n "${NEKOSHELL_PANEL:-}" ]] && exit 0
if [[ -n "${SSH_CONNECTION:-}" && -z "${NEKOSHELL_GREET_SSH:-}" ]]; then exit 0; fi

command -v fastfetch >/dev/null 2>&1 || exit 0

# shellcheck source=../lib/paths.sh
source "$(dirname "$(readlink "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")/../lib/paths.sh"

start_ns=$(date +%s%N 2>/dev/null || echo 0)

POKEMON_SHARE=70
SHINY_ODDS=128
GENERATIONS=""
IMAGE_WIDTH=28
IMAGE_HEIGHT=14
if [[ -r "$NEKOSHELL_CONFIG/greet.conf" ]]; then
  # shellcheck source=/dev/null
  source "$NEKOSHELL_CONFIG/greet.conf"
fi

[[ -n "${NEKOSHELL_SEED:-}" ]] && RANDOM="$NEKOSHELL_SEED"
mkdir -p "$NEKOSHELL_CACHE"
ff_config="$HOME/.config/fastfetch/config.jsonc"

pick_image() {
  # Print a random image path from the art pack, or nothing.
  local files=() f
  for f in "$NEKOSHELL_CONFIG"/art/*.png "$NEKOSHELL_CONFIG"/art/*.jpg "$NEKOSHELL_CONFIG"/art/*.jpeg; do
    [[ -f "$f" ]] && files+=("$f")
  done
  [[ ${#files[@]} -eq 0 ]] && return 0
  printf '%s\n' "${files[$((RANDOM % ${#files[@]}))]}"
}

show_pokemon() {
  command -v pokemon-colorscripts >/dev/null 2>&1 || return 0
  local args=(-r) out name
  [[ -n "$GENERATIONS" ]] && args+=("$GENERATIONS")
  local shiny=""
  if (( SHINY_ODDS > 0 )) && (( RANDOM % SHINY_ODDS == 0 )); then
    args+=(-s); shiny=" ✦ shiny"
  fi
  out="$(pokemon-colorscripts "${args[@]}" 2>/dev/null)" || return 0
  name="${out%%$'\n'*}"
  printf '%s%s\n' "$name" "$shiny" > "$NEKOSHELL_CACHE/art-name"
  printf '%s\n' "${out#*$'\n'}" | fastfetch --config "$ff_config" --file-raw -
}

show_image() {
  local img="$1"
  basename "$img" > "$NEKOSHELL_CACHE/art-name"
  fastfetch --config "$ff_config" --iterm "$img" --logo-width "$IMAGE_WIDTH" --logo-height "$IMAGE_HEIGHT"
}

roll=$((RANDOM % 100))
img=""
if (( roll >= POKEMON_SHARE )) && [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]]; then
  img="$(pick_image)"
fi

if [[ -n "$img" ]]; then
  show_image "$img"
else
  show_pokemon
fi

if [[ -n "${NEKOSHELL_GREET_TIME:-}" && "$start_ns" != 0 ]]; then
  end_ns=$(date +%s%N)
  printf 'greet: %d ms\n' $(( (end_ns - start_ns) / 1000000 ))
fi
exit 0
```

Note: macOS `date` has no `%N`; `date +%s%N` prints a literal `N`. Use `python3 -c 'import time;print(int(time.time()*1000))'` only when `NEKOSHELL_GREET_TIME` is set (so the normal path stays Python-free). Implement `now_ms()` that way and compute `start_ms` only when timing is requested.

- [ ] **Step 5: Write bin/nekoshell-art, scripts/gen-sample-art.py, art/README.md**

`bin/nekoshell-art`:
```bash
#!/usr/bin/env bash
# Manage the greeting art pack in ~/.config/nekoshell/art.
set -euo pipefail
# shellcheck source=../lib/paths.sh
source "$(dirname "$(readlink "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")/../lib/paths.sh"

ART_DIR="$NEKOSHELL_CONFIG/art"
usage() {
  cat <<'EOF'
usage: nekoshell-art <command>
  list          files in the art pack
  add <image>   copy a PNG/JPG into the art pack
  sample        copy the shipped sample images into the art pack
EOF
}

case "${1:-}" in
  list)
    mkdir -p "$ART_DIR"
    find "$ART_DIR" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) -exec basename {} \; | sort
    ;;
  add)
    [[ -f "${2:-}" ]] || { echo "nekoshell-art: no such file: ${2:-}" >&2; exit 1; }
    mkdir -p "$ART_DIR"
    cp "$2" "$ART_DIR/"
    echo "added $(basename "$2")"
    ;;
  sample)
    mkdir -p "$ART_DIR"
    cp "$NEKOSHELL_ROOT"/art/*.png "$ART_DIR/"
    echo "copied $(ls "$NEKOSHELL_ROOT"/art/*.png | wc -l | tr -d ' ') sample images"
    ;;
  *) usage; exit 2 ;;
esac
```

`scripts/gen-sample-art.py` (pure Python PNG writer; no Pillow):
```python
#!/usr/bin/env python3
"""Generate the sample pixel-art PNGs in art/. Original artwork, MIT."""
import struct
import zlib
from pathlib import Path

SCALE = 12
PALETTE = {"P": (203, 166, 247), "W": (205, 214, 244), "K": (30, 30, 46), "R": (245, 194, 231),
           "N": (250, 179, 135), "G": (166, 227, 161), "B": (137, 180, 250), "Y": (249, 226, 175)}

SPRITES = {
    "neko": [
        "....P......P....", "...PP......PP...", "...PPP....PPP...", "..PPPPPPPPPPPP..",
        "..PPPPPPPPPPPP..", ".PPPPPPPPPPPPPP.", ".PPWWPPPPPPWWPP.", ".PPWKPPPPPPWKPP.",
        ".PPPPPPPPPPPPPP.", ".PRRPPPPNPPPPRR.", ".PRRPPPNNNPPPRR.", "..PPPPPPPPPPPP..",
        "..PPPPPPPPPPPP..", "...PPPPPPPPPP...", "....PP....PP....", "................"],
    "ghost": [
        "................", ".....BBBBBB.....", "....BBBBBBBB....", "...BBBBBBBBBB...",
        "...BBWWBBBBWWB..", "...BBWKBBBBWKB..", "...BBBBBBBBBBB..", "...BBBBBBBBBBB..",
        "...BBBBBBBBBBB..", "...BBBBBBBBBBB..", "...BBBBBBBBBBB..", "...BBBBBBBBBBB..",
        "...BB.BBBB.BBB..", "...B...BB...B...", "................", "................"],
    "slime": [
        "................", "................", "......GGGG......", "....GGGGGGGG....",
        "...GGGGGGGGGG...", "..GGGGGGGGGGGG..", "..GGWWGGGGWWGG..", "..GGWKGGGGWKGG..",
        ".GGGGGGGGGGGGGG.", ".GGGGGGGGGGGGGG.", ".GGGGGYYYYGGGGG.", ".GGGGGGGGGGGGGG.",
        "..GGGGGGGGGGGG..", "...GGGGGGGGGG...", "................", "................"],
}


def png_bytes(rows):
    h = len(rows) * SCALE
    w = len(rows[0]) * SCALE
    raw = bytearray()
    for row in rows:
        line = bytearray()
        for ch in row:
            rgba = PALETTE[ch] + (255,) if ch in PALETTE else (0, 0, 0, 0)
            line += bytes(rgba) * SCALE
        for _ in range(SCALE):
            raw += b"\x00" + line

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")


def main():
    out = Path(__file__).resolve().parent.parent / "art"
    out.mkdir(exist_ok=True)
    for name, rows in SPRITES.items():
        (out / f"{name}.png").write_bytes(png_bytes(rows))
        print(f"wrote art/{name}.png")


if __name__ == "__main__":
    main()
```

Run it once: `python3 scripts/gen-sample-art.py` and commit the three PNGs.

`art/README.md`:
```markdown
# Art pack samples

`neko.png`, `ghost.png` and `slime.png` are original pixel art generated by `scripts/gen-sample-art.py`. They are MIT licensed like the rest of the repo.

nekoshell does not ship anime stills or Pokémon sprites: those are copyrighted. Pokémon art comes from the pokemon-colorscripts project at greeting time. To use your own images:

    nekoshell-art add ~/Pictures/my-favourite.png
    nekoshell-art list

Images live in `~/.config/nekoshell/art/`. PNG and JPG work. Transparent PNGs look best. Size is set in `~/.config/nekoshell/greet.conf` (`IMAGE_WIDTH`, `IMAGE_HEIGHT`, in terminal cells).
```

- [ ] **Step 6: Run the tests and shellcheck**

Run: `chmod +x bin/* tests/fakes/*; bats tests/greet.bats && shellcheck -x bin/nekoshell-greet bin/nekoshell-art`
Expected: 13 tests pass, no shellcheck output.

- [ ] **Step 7: Commit**

```bash
git add bin/nekoshell-greet bin/nekoshell-art stow/config/.config/fastfetch stow/config/.config/nekoshell/greet.conf scripts/gen-sample-art.py art tests/greet.bats tests/fakes
git commit -m "feat: greeting with pokemon colourscripts, art pack and fastfetch"
```

---

### Task 5: Spotify panel launcher and spotify_player config

**Files:**
- Create: `bin/nekoshell-music`, `stow/config/.config/spotify-player/app.toml`, `stow/config/.config/spotify-player/theme.toml`, `tests/music.bats`, `tests/fakes/spotify_player`, `tests/fakes/spotify`

**Interfaces:**
- Consumes: `lib/paths.sh`.
- Produces: `nekoshell-music [--remote]`. Exec order: spotify_player with cached credentials, else authenticate then spotify_player, else the shpotify remote. `NEKOSHELL_PANEL=1` exported.

- [ ] **Step 1: Write the fakes and failing tests**

`tests/fakes/spotify_player`:
```bash
#!/usr/bin/env bash
echo "spotify_player $*"
echo "PANEL=${NEKOSHELL_PANEL:-unset}"
```

`tests/fakes/spotify`:
```bash
#!/usr/bin/env bash
echo "spotify $*"
```

`tests/music.bats`:
```bash
#!/usr/bin/env bats
load helpers

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  unset NEKOSHELL_PANEL
}
teardown() { teardown_tmp_home; }

@test "runs spotify_player when credentials are cached" {
  mkdir -p "$HOME/.cache/spotify-player"
  touch "$HOME/.cache/spotify-player/credentials.json"
  run "$REPO_ROOT/bin/nekoshell-music"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "spotify_player " ]
  [ "${lines[1]}" = "PANEL=1" ]
}

@test "authenticates first when no credentials are cached" {
  run "$REPO_ROOT/bin/nekoshell-music"
  [ "$status" -eq 0 ]
  [[ "$output" == *"spotify_player authenticate"* ]]
  [[ "${lines[-2]}" == "spotify_player " ]]
}

@test "--remote drives shpotify with single keys" {
  run bash -c "printf 'ns q' | '$REPO_ROOT/bin/nekoshell-music' --remote"
  [ "$status" -eq 0 ]
  [[ "$output" == *"spotify next"* ]]
  [[ "$output" == *"spotify status"* ]]
  [[ "$output" == *"spotify pause"* ]]
}

@test "falls back to the remote when spotify_player is missing" {
  mkdir -p "$HOME/bin"; cp "$REPO_ROOT/tests/fakes/spotify" "$HOME/bin/"
  run bash -c "printf 'q' | PATH='$HOME/bin:/usr/bin:/bin' '$REPO_ROOT/bin/nekoshell-music'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"remote"* ]]
}

@test "spotify_player config selects the mocha theme and the nekoshell device" {
  run python3 -c "
import tomllib
a=tomllib.load(open('$REPO_ROOT/stow/config/.config/spotify-player/app.toml','rb'))
t=tomllib.load(open('$REPO_ROOT/stow/config/.config/spotify-player/theme.toml','rb'))
print(a['theme'], a['enable_media_control'], a['device']['name'], a['device']['volume'], a['device']['bitrate'])
print(t['themes'][0]['name'], t['themes'][0]['palette']['background'])"
  [ "${lines[0]}" = "catppuccin_mocha False nekoshell 70 320" ]
  [ "${lines[1]}" = "catppuccin_mocha #1e1e2e" ]
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bats tests/music.bats`
Expected: FAIL, `bin/nekoshell-music: No such file`.

- [ ] **Step 3: Write the configs**

`stow/config/.config/spotify-player/app.toml`:
```toml
theme = "catppuccin_mocha"
enable_media_control = false
enable_notify = false
playback_window_position = "Top"
playback_window_height = 6
client_port = 8080

[device]
name = "nekoshell"
device_type = "computer"
volume = 70
bitrate = 320
audio_cache = false
normalization = false
autoplay = false
```

`stow/config/.config/spotify-player/theme.toml`:
```toml
[[themes]]
name = "catppuccin_mocha"

[themes.palette]
background = "#1e1e2e"
foreground = "#cdd6f4"
black = "#45475a"
red = "#f38ba8"
green = "#a6e3a1"
yellow = "#f9e2af"
blue = "#89b4fa"
magenta = "#f5c2e7"
cyan = "#94e2d5"
white = "#bac2de"
bright_black = "#585b70"
bright_red = "#f38ba8"
bright_green = "#a6e3a1"
bright_yellow = "#f9e2af"
bright_blue = "#89b4fa"
bright_magenta = "#f5c2e7"
bright_cyan = "#94e2d5"
bright_white = "#a6adc8"

[themes.component_style]
block_title = { fg = "Magenta", modifiers = ["Bold"] }
border = { fg = "BrightBlack" }
playback_track = { fg = "Cyan", modifiers = ["Bold"] }
playback_artists = { fg = "Cyan", modifiers = ["Bold"] }
playback_album = { fg = "Yellow" }
playback_metadata = { fg = "BrightBlack" }
playback_progress_bar = { bg = "BrightBlack", fg = "Green" }
current_playing = { fg = "Green", modifiers = ["Bold"] }
page_desc = { fg = "Cyan", modifiers = ["Bold"] }
table_header = { fg = "Blue" }
selection = { fg = "Magenta", modifiers = ["Bold"] }
```

- [ ] **Step 4: Write bin/nekoshell-music**

```bash
#!/usr/bin/env bash
# nekoshell-music: what runs inside the Spotify panel.
# Premium: spotify_player (streams on its own). Fallback: shpotify remote for the desktop app.
set -euo pipefail
export NEKOSHELL_PANEL=1

mode="${1:-auto}"

remote() {
  command -v spotify >/dev/null 2>&1 || {
    echo "nekoshell: neither spotify_player nor shpotify is installed. Run: brew install spotify_player shpotify" >&2
    exit 1
  }
  cat <<'EOF'
nekoshell remote (shpotify -> Spotify desktop app)
  space  play/pause     n  next     p  previous
  +/-    volume         s  status   q  quit
EOF
  local key
  while IFS= read -r -s -n 1 key; do
    case "$key" in
      " ") spotify pause ;;
      n) spotify next ;;
      p) spotify prev ;;
      +) spotify vol up ;;
      -) spotify vol down ;;
      s) spotify status ;;
      q) break ;;
    esac
  done
}

if [[ "$mode" == "--remote" ]] || ! command -v spotify_player >/dev/null 2>&1; then
  remote
  exit 0
fi

cache="$HOME/.cache/spotify-player"
if ! ls "$cache"/credentials* >/dev/null 2>&1; then
  echo "nekoshell: first run, logging in to Spotify. A browser window will open."
  echo "           You need a Spotify Premium account for playback."
  spotify_player authenticate
fi
exec spotify_player
```

- [ ] **Step 5: Run the tests and shellcheck**

Run: `chmod +x bin/nekoshell-music tests/fakes/spotify_player tests/fakes/spotify; bats tests/music.bats && shellcheck -x bin/nekoshell-music`
Expected: 5 tests pass, no shellcheck output. The fake `spotify_player` is not `exec`-replaced in a way that hides output because the fake prints before exiting.

- [ ] **Step 6: Commit**

```bash
git add bin/nekoshell-music stow/config/.config/spotify-player tests/music.bats tests/fakes/spotify_player tests/fakes/spotify
git commit -m "feat: spotify panel launcher with spotify_player and shpotify remote"
```

---

### Task 6: Installer, backup, doctor, uninstaller

**Files:**
- Create: `install.sh`, `uninstall.sh`, `lib/backup.sh`, `bin/nekoshell-doctor`, `deps.lock`, `tests/install.bats`, `tests/doctor.bats`, `tests/fakes/brew`, `tests/fakes/git`, `tests/fakes/defaults`, `tests/fakes/pgrep`

**Interfaces:**
- Consumes: `lib/log.sh`, `lib/paths.sh`, `lib/iterm.sh`, `lib/zsh_migrate.sh`, `iterm2/build-profiles.py`, `stow/`.
- Produces: `install.sh [--check] [--dry-run] [--yes] [--skip-brew] [--skip-spotify] [--iterm-prefs]`; `uninstall.sh [--yes]`; `nekoshell-doctor [--json]` exit 0 when no `fail`; `lib/backup.sh` functions `backup_path REL_PATH` (moves `$HOME/REL_PATH` into the current backup dir and appends to `manifest.txt`), `backup_begin` (creates `$NEKOSHELL_BACKUP_ROOT/<UTC ts>` and exports `NEKOSHELL_BACKUP_DIR`), `backup_restore_latest`.
- `deps.lock` content: `pokemon-colorscripts=<40-char commit sha of gitlab.com/phoneybadger/pokemon-colorscripts main at the time of this task>` (look it up with `git ls-remote https://gitlab.com/phoneybadger/pokemon-colorscripts.git main`).

- [ ] **Step 1: Write the fakes and failing tests**

Fakes (each `chmod +x`):

`tests/fakes/brew`: `#!/usr/bin/env bash` then `echo "brew $*"`; when `$1` is `--prefix` print `/opt/homebrew`.
`tests/fakes/git`: if the args contain `clone`, `mkdir -p "${@: -1}"` and create `"${@: -1}/pokemon-colorscripts.py"` with a shebang that echoes `pikachu`; if they contain `checkout` or `-C`, exit 0; always echo `git $*`.
`tests/fakes/defaults`: `echo "defaults $*"`; for `read` print `NONE`.
`tests/fakes/pgrep`: exit 1 (iTerm2 not running) unless `FAKE_ITERM_RUNNING=1`.

`tests/install.bats`:
```bash
#!/usr/bin/env bats
load helpers

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_SKIP_PREFLIGHT=1
  printf 'export EDITOR=vim\nalias gs="git status"\nexport ZSH="$HOME/.oh-my-zsh"\n' > "$HOME/.zshrc"
  echo 'old' > "$HOME/.config/starship.toml"
}
teardown() { teardown_tmp_home; }

@test "--dry-run runs nothing and prints the plan" {
  run "$REPO_ROOT/install.sh" --dry-run --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"brew bundle"* ]]
  [[ "$output" == *"stow"* ]]
  [ ! -L "$HOME/.zshrc" ]
  [ "$(cat "$HOME/.config/starship.toml")" = "old" ]
}

@test "install backs up, migrates aliases, stows, records root, writes the profile" {
  run "$REPO_ROOT/install.sh" --yes
  [ "$status" -eq 0 ]
  [ -L "$HOME/.zshrc" ]
  [ "$(readlink "$HOME/.zshrc")" = "$REPO_ROOT/stow/zsh/.zshrc" ]
  [ "$(cat "$HOME/.config/nekoshell/root")" = "$REPO_ROOT" ]
  backup="$(ls -d "$HOME"/.local/share/nekoshell/backup/*/ | head -1)"
  [ -f "$backup/.zshrc" ]
  [ "$(cat "$backup/.config/starship.toml")" = "old" ]
  grep -q '^\.zshrc$' "$backup/manifest.txt"
  grep -q 'alias gs="git status"' "$HOME/.config/nekoshell/zsh/local.zsh"
  ! grep -q 'oh-my-zsh' "$HOME/.config/nekoshell/zsh/local.zsh"
  [ -f "$HOME/Library/Application Support/iTerm2/DynamicProfiles/nekoshell.json" ]
  [ -L "$HOME/.local/bin/pokemon-colorscripts" ]
  grep -q 'nekoshell' "$HOME/.gitconfig"
  [[ "$output" == *"Default Bookmark Guid"* ]]
}

@test "install is idempotent" {
  "$REPO_ROOT/install.sh" --yes
  run "$REPO_ROOT/install.sh" --yes
  [ "$status" -eq 0 ]
  [ "$(ls -d "$HOME"/.local/share/nekoshell/backup/*/ | wc -l | tr -d ' ')" = "1" ]
  [ "$(grep -c 'nekoshell' "$HOME/.gitconfig")" = "1" ]
}

@test "--check after install reports nothing to do" {
  "$REPO_ROOT/install.sh" --yes
  run "$REPO_ROOT/install.sh" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to do"* ]]
}

@test "prefs are deferred while iTerm2 is running" {
  FAKE_ITERM_RUNNING=1 run "$REPO_ROOT/install.sh" --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"pending"* ]]
  [[ "$output" == *"install.sh --iterm-prefs"* ]]
}

@test "uninstall restores the backup" {
  "$REPO_ROOT/install.sh" --yes
  run "$REPO_ROOT/uninstall.sh" --yes
  [ "$status" -eq 0 ]
  [ ! -L "$HOME/.zshrc" ]
  grep -q 'EDITOR=vim' "$HOME/.zshrc"
  [ "$(cat "$HOME/.config/starship.toml")" = "old" ]
  [ ! -f "$HOME/Library/Application Support/iTerm2/DynamicProfiles/nekoshell.json" ]
}
```

`tests/doctor.bats`:
```bash
#!/usr/bin/env bats
load helpers

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_SKIP_PREFLIGHT=1
  export TERM_PROGRAM=iTerm.app
}
teardown() { teardown_tmp_home; }

@test "doctor fails before install" {
  run "$REPO_ROOT/bin/nekoshell-doctor"
  [ "$status" -ne 0 ]
  [[ "$output" == *"fail"* ]]
}

@test "doctor passes with only warns after a fake install" {
  "$REPO_ROOT/install.sh" --yes >/dev/null
  mkdir -p "$HOME/Library/Fonts"; touch "$HOME/Library/Fonts/JetBrainsMonoNerdFont-Regular.ttf"
  run "$REPO_ROOT/bin/nekoshell-doctor"
  [ "$status" -eq 0 ]
  [[ "$output" != *"fail"* ]]
  [[ "$output" == *"warn"*"spotify"* ]]
}

@test "doctor --json emits an array of checks" {
  "$REPO_ROOT/install.sh" --yes >/dev/null
  run bash -c "'$REPO_ROOT/bin/nekoshell-doctor' --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(type(d).__name__, all(k in d[0] for k in (\"check\",\"status\",\"detail\")))'"
  [ "$output" = "list True" ]
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bats tests/install.bats tests/doctor.bats`
Expected: FAIL, `install.sh: No such file`.

- [ ] **Step 3: Write lib/backup.sh**

```bash
#!/usr/bin/env bash
# Backups of files the installer replaces. Requires lib/log.sh and lib/paths.sh.

# backup_begin: create a timestamped backup dir (lazily, on first backup_path call).
backup_begin() {
  NEKOSHELL_BACKUP_DIR="$NEKOSHELL_BACKUP_ROOT/$(date -u +%Y%m%dT%H%M%SZ)"
  export NEKOSHELL_BACKUP_DIR
}

# backup_path REL: move $HOME/REL (file, dir or foreign symlink) into the backup dir.
# Symlinks that already point into NEKOSHELL_ROOT are left alone (idempotent re-runs).
backup_path() {
  local rel="$1" src="$HOME/$1" target
  [[ -e "$src" || -L "$src" ]] || return 0
  if [[ -L "$src" ]]; then
    target="$(readlink "$src")"
    [[ "$target" == "$NEKOSHELL_ROOT"/* ]] && return 0
  fi
  run mkdir -p "$NEKOSHELL_BACKUP_DIR/$(dirname "$rel")"
  run mv "$src" "$NEKOSHELL_BACKUP_DIR/$rel"
  if [[ "$NEKOSHELL_DRY_RUN" != "1" ]]; then
    printf '%s\n' "$rel" >> "$NEKOSHELL_BACKUP_DIR/manifest.txt"
  fi
}

# backup_restore_latest: move every manifest entry of the newest backup back into $HOME.
backup_restore_latest() {
  local latest rel
  latest="$(ls -d "$NEKOSHELL_BACKUP_ROOT"/*/ 2>/dev/null | sort | tail -1)"
  [[ -n "$latest" && -r "$latest/manifest.txt" ]] || { log_warn "no backup to restore"; return 0; }
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    run rm -rf "$HOME/$rel"
    run mkdir -p "$HOME/$(dirname "$rel")"
    run mv "$latest/$rel" "$HOME/$rel"
  done < "$latest/manifest.txt"
  log_ok "restored $(wc -l < "$latest/manifest.txt" | tr -d ' ') paths from $latest"
}
```

- [ ] **Step 4: Write install.sh**

```bash
#!/usr/bin/env bash
# nekoshell installer. Idempotent. Re-run any time.
set -euo pipefail

NEKOSHELL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export NEKOSHELL_ROOT
# shellcheck source=lib/log.sh
source "$NEKOSHELL_ROOT/lib/log.sh"
# shellcheck source=lib/paths.sh
source "$NEKOSHELL_ROOT/lib/paths.sh"
# shellcheck source=lib/backup.sh
source "$NEKOSHELL_ROOT/lib/backup.sh"
# shellcheck source=lib/iterm.sh
source "$NEKOSHELL_ROOT/lib/iterm.sh"
# shellcheck source=lib/zsh_migrate.sh
source "$NEKOSHELL_ROOT/lib/zsh_migrate.sh"

CHECK=0; YES=0; SKIP_BREW=0; SKIP_SPOTIFY=0; ONLY_PREFS=0
for arg in "$@"; do
  case "$arg" in
    --check) CHECK=1 ;;
    --dry-run) NEKOSHELL_DRY_RUN=1; export NEKOSHELL_DRY_RUN ;;
    --yes|-y) YES=1 ;;
    --skip-brew) SKIP_BREW=1 ;;
    --skip-spotify) SKIP_SPOTIFY=1 ;;
    --iterm-prefs) ONLY_PREFS=1 ;;
    -h|--help)
      sed -n '2,3p' "$0"
      echo "usage: install.sh [--check] [--dry-run] [--yes] [--skip-brew] [--skip-spotify] [--iterm-prefs]"
      exit 0 ;;
    *) log_fail "unknown flag: $arg"; exit 2 ;;
  esac
done

TOTAL=10
STOWED_PATHS=(.zshrc .config/starship.toml .config/fastfetch .config/spotify-player .config/bat .config/btop .config/lazygit .config/nekoshell/zsh/env.zsh .config/nekoshell/zsh/aliases.zsh .config/nekoshell/zsh/plugins.txt .config/nekoshell/greet.conf .config/nekoshell/git)

confirm() {
  [[ "$YES" == 1 ]] && return 0
  printf '%s [y/N] ' "$1"
  read -r reply
  [[ "$reply" == y* || "$reply" == Y* ]]
}

preflight() {
  [[ -n "${NEKOSHELL_SKIP_PREFLIGHT:-}" ]] && return 0
  [[ "$(uname -s)" == "Darwin" ]] || { log_fail "nekoshell v0.1 supports macOS only"; exit 1; }
  command -v brew >/dev/null 2>&1 || {
    log_fail "Homebrew is required. Install it first:"
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
  }
  command -v zsh >/dev/null 2>&1 || { log_fail "zsh not found"; exit 1; }
  command -v stow >/dev/null 2>&1 || [[ "$SKIP_BREW" == 0 ]] || { log_fail "stow is missing and --skip-brew was given"; exit 1; }
}

# --check: list what would change. Exit 0 with "nothing to do" when installed.
check_only() {
  local todo=0
  [[ "$(readlink "$HOME/.zshrc" 2>/dev/null)" == "$NEKOSHELL_ROOT/stow/zsh/.zshrc" ]] || { log_info "would stow ~/.zshrc"; todo=1; }
  [[ "$(cat "$NEKOSHELL_CONFIG/root" 2>/dev/null)" == "$NEKOSHELL_ROOT" ]] || { log_info "would record root"; todo=1; }
  [[ -f "$ITERM_DYNAMIC_DIR/nekoshell.json" ]] || { log_info "would write iTerm2 profiles"; todo=1; }
  [[ -L "$HOME/.local/bin/pokemon-colorscripts" ]] || { log_info "would install pokemon-colorscripts"; todo=1; }
  if iterm_prefs_pending; then log_info "iTerm2 global prefs pending (run: ./install.sh --iterm-prefs with iTerm2 closed)"; fi
  if [[ "$todo" == 0 ]]; then log_ok "nothing to do"; fi
  exit 0
}

apply_prefs_step() {
  if iterm_is_running; then
    log_warn "iTerm2 is running; global prefs are pending. Quit iTerm2, then run from Terminal.app:"
    echo "  $NEKOSHELL_ROOT/install.sh --iterm-prefs"
    return 0
  fi
  iterm_apply_prefs
  log_ok "iTerm2 global prefs applied"
}

install_pokemon_colorscripts() {
  local dest="$HOME/.local/share/pokemon-colorscripts" sha
  sha="$(sed -n 's/^pokemon-colorscripts=//p' "$NEKOSHELL_ROOT/deps.lock")"
  if [[ ! -d "$dest" ]]; then
    run git clone --quiet https://gitlab.com/phoneybadger/pokemon-colorscripts.git "$dest"
  fi
  run git -C "$dest" checkout --quiet "$sha"
  run mkdir -p "$HOME/.local/bin"
  run ln -sfn "$dest/pokemon-colorscripts.py" "$HOME/.local/bin/pokemon-colorscripts"
  run chmod +x "$dest/pokemon-colorscripts.py"
}

add_gitconfig_include() {
  local marker="# nekoshell delta" gc="$HOME/.gitconfig"
  if [[ -r "$gc" ]] && grep -q "$marker" "$gc"; then return 0; fi
  if [[ "$NEKOSHELL_DRY_RUN" == "1" ]]; then log_info "would add delta include to ~/.gitconfig"; return 0; fi
  printf '\n%s\n[include]\n\tpath = %s\n' "$marker" "$NEKOSHELL_CONFIG/git/delta.gitconfig" >> "$gc"
}

main() {
  preflight
  [[ "$ONLY_PREFS" == 1 ]] && { iterm_apply_prefs; log_ok "iTerm2 global prefs applied"; exit 0; }
  [[ "$CHECK" == 1 ]] && check_only

  log_step 1 $TOTAL "Preflight"
  log_ok "macOS, Homebrew, zsh present. Checkout: $NEKOSHELL_ROOT"
  confirm "Install nekoshell into $HOME?" || { log_warn "aborted"; exit 1; }

  log_step 2 $TOTAL "Homebrew packages"
  if [[ "$SKIP_BREW" == 1 ]]; then log_warn "skipped (--skip-brew)"; else
    run brew bundle --file "$NEKOSHELL_ROOT/Brewfile" --no-upgrade
  fi

  log_step 3 $TOTAL "Back up files nekoshell replaces"
  backup_begin
  local rel old_zshrc=""
  [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]] && old_zshrc="$NEKOSHELL_BACKUP_DIR/.zshrc"
  for rel in "${STOWED_PATHS[@]}"; do backup_path "$rel"; done
  if [[ -d "$NEKOSHELL_BACKUP_DIR" ]]; then log_ok "backup at $NEKOSHELL_BACKUP_DIR"; else log_ok "nothing to back up"; fi

  log_step 4 $TOTAL "Migrate your aliases"
  run mkdir -p "$NEKOSHELL_CONFIG/zsh"
  if [[ -n "$old_zshrc" && "$NEKOSHELL_DRY_RUN" != "1" ]]; then
    log_ok "$(zsh_migrate_aliases "$old_zshrc" "$NEKOSHELL_CONFIG/zsh/local.zsh") lines copied to ~/.config/nekoshell/zsh/local.zsh"
  else
    log_info "no previous .zshrc to migrate"
  fi

  log_step 5 $TOTAL "Link configs with stow"
  run stow --dir "$NEKOSHELL_ROOT/stow" --target "$HOME" --restow zsh config

  log_step 6 $TOTAL "Record checkout location"
  run mkdir -p "$NEKOSHELL_CONFIG" "$NEKOSHELL_CACHE"
  if [[ "$NEKOSHELL_DRY_RUN" != "1" ]]; then printf '%s\n' "$NEKOSHELL_ROOT" > "$NEKOSHELL_CONFIG/root"; fi

  log_step 7 $TOTAL "pokemon-colorscripts"
  install_pokemon_colorscripts

  log_step 8 $TOTAL "git delta include"
  add_gitconfig_include

  log_step 9 $TOTAL "iTerm2 profiles"
  iterm_write_profiles
  log_ok "profiles: nekoshell, nekoshell panel (hotkey ⌥M)"

  log_step 10 $TOTAL "iTerm2 global preferences"
  apply_prefs_step

  echo
  log_ok "installed. Human steps left:"
  echo "  1. Quit and reopen iTerm2 (pick the 'nekoshell' profile if it is not the default)."
  [[ "$SKIP_SPOTIFY" == 1 ]] || echo "  2. Run: spotify_player authenticate   (opens a browser; needs Spotify Premium)"
  echo "  3. Press ⌥M anywhere for the Spotify panel. Run nekoshell-doctor to verify."
}

main
```

Notes for the implementer: `--dry-run` must not create the backup dir, so `backup_path` only `run`s `mkdir`/`mv` (already dry-run aware) and skips writing the manifest. `--check` must be answerable without Homebrew, so it never calls `brew`. Under the test fakes, `git clone` creates the destination.

- [ ] **Step 5: Write uninstall.sh**

```bash
#!/usr/bin/env bash
# Undo install.sh: unstow, restore the newest backup, remove the iTerm2 profiles.
set -euo pipefail
NEKOSHELL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export NEKOSHELL_ROOT
# shellcheck source=lib/log.sh
source "$NEKOSHELL_ROOT/lib/log.sh"
# shellcheck source=lib/paths.sh
source "$NEKOSHELL_ROOT/lib/paths.sh"
# shellcheck source=lib/backup.sh
source "$NEKOSHELL_ROOT/lib/backup.sh"

YES=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y) YES=1 ;;
    --dry-run) NEKOSHELL_DRY_RUN=1; export NEKOSHELL_DRY_RUN ;;
    *) log_fail "unknown flag: $arg"; exit 2 ;;
  esac
done
if [[ "$YES" != 1 ]]; then
  printf 'Remove nekoshell links and restore your previous files? [y/N] '
  read -r reply; [[ "$reply" == y* || "$reply" == Y* ]] || exit 1
fi

run stow --dir "$NEKOSHELL_ROOT/stow" --target "$HOME" --delete zsh config
backup_restore_latest
run rm -f "$ITERM_DYNAMIC_DIR/nekoshell.json" "$NEKOSHELL_CONFIG/root"
log_ok "nekoshell removed. Homebrew packages were left in place; to remove them:"
echo "  brew bundle cleanup --file $NEKOSHELL_ROOT/Brewfile --force"
echo "  (and: defaults delete com.googlecode.iterm2 'Default Bookmark Guid')"
```

- [ ] **Step 6: Write bin/nekoshell-doctor**

```bash
#!/usr/bin/env bash
# nekoshell-doctor: one line per check. Exit 1 if any check fails. --json for agents.
set -uo pipefail
# shellcheck source=../lib/paths.sh
source "$(dirname "$(readlink "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")/../lib/paths.sh"
# shellcheck source=../lib/iterm.sh
source "$NEKOSHELL_ROOT/lib/iterm.sh"

JSON=0; [[ "${1:-}" == "--json" ]] && JSON=1
FAILS=0; ROWS=""

report() { # status check detail
  local status="$1" check="$2" detail="$3"
  [[ "$status" == "fail" ]] && FAILS=$((FAILS + 1))
  if [[ "$JSON" == 1 ]]; then
    ROWS+="$(printf '{"check":"%s","status":"%s","detail":"%s"},' "$check" "$status" "${detail//\"/\\\"}")"
  else
    printf '%-4s %-28s %s\n' "$status" "$check" "$detail"
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

if have brew; then report ok "homebrew" "$(brew --version | head -1)"; else report fail "homebrew" "not on PATH"; fi
for tool in starship fastfetch fzf eza bat zoxide stow; do
  if have "$tool"; then report ok "tool: $tool" "$(command -v "$tool")"; else report fail "tool: $tool" "missing (brew bundle)"; fi
done
if ls "$HOME"/Library/Fonts/JetBrainsMonoNerdFont* /Library/Fonts/JetBrainsMonoNerdFont* >/dev/null 2>&1; then
  report ok "font" "JetBrainsMono Nerd Font"; else report fail "font" "brew install --cask font-jetbrains-mono-nerd-font"; fi
if [[ "$(readlink "$HOME/.zshrc" 2>/dev/null)" == "$NEKOSHELL_ROOT/stow/zsh/.zshrc" ]]; then
  report ok "zshrc" "linked to $NEKOSHELL_ROOT"; else report fail "zshrc" "not a nekoshell symlink (run install.sh)"; fi
if [[ "$(cat "$NEKOSHELL_CONFIG/root" 2>/dev/null)" == "$NEKOSHELL_ROOT" ]]; then
  report ok "root" "$NEKOSHELL_ROOT"; else report fail "root" "~/.config/nekoshell/root missing or stale"; fi
prof="$ITERM_DYNAMIC_DIR/nekoshell.json"
if [[ -f "$prof" ]] && grep -q "$NEKOSHELL_MAIN_GUID" "$prof" && grep -q "$NEKOSHELL_PANEL_GUID" "$prof"; then
  report ok "iterm2 profiles" "$prof"; else report fail "iterm2 profiles" "missing (run install.sh)"; fi
if iterm_prefs_pending; then
  report warn "iterm2 prefs" "pending: quit iTerm2, run install.sh --iterm-prefs"; else report ok "iterm2 prefs" "default profile is nekoshell"; fi
if have pokemon-colorscripts && pokemon-colorscripts -r >/dev/null 2>&1; then
  report ok "pokemon-colorscripts" "$(command -v pokemon-colorscripts)"; else report fail "pokemon-colorscripts" "missing or broken"; fi
if have fastfetch; then
  ms="$(NEKOSHELL_SEED=1 NEKOSHELL_GREET_TIME=1 NEKOSHELL_NO_GREET= script -q /dev/null "$NEKOSHELL_ROOT/bin/nekoshell-greet" </dev/null 2>/dev/null | tr -d '\r' | sed -n 's/^greet: \([0-9]*\) ms$/\1/p')"
  if [[ -z "$ms" ]]; then report warn "greet time" "could not measure"
  elif (( ms <= 150 )); then report ok "greet time" "${ms} ms"
  else report warn "greet time" "${ms} ms (budget 150)"; fi
fi
if have spotify_player; then
  if ls "$HOME"/.cache/spotify-player/credentials* >/dev/null 2>&1; then report ok "spotify" "logged in"
  else report warn "spotify" "run: spotify_player authenticate"; fi
else report warn "spotify" "spotify_player not installed"; fi

if [[ "$JSON" == 1 ]]; then printf '[%s]\n' "${ROWS%,}"; fi
[[ "$FAILS" == 0 ]]
```

- [ ] **Step 7: Run all tests and shellcheck**

Run: `chmod +x install.sh uninstall.sh bin/nekoshell-doctor tests/fakes/*; shellcheck -x install.sh uninstall.sh lib/*.sh bin/* && bats tests`
Expected: every bats file passes (`tests/install.bats` 6, `tests/doctor.bats` 3, plus earlier files), no shellcheck output.

- [ ] **Step 8: Commit**

```bash
git add install.sh uninstall.sh lib/backup.sh bin/nekoshell-doctor deps.lock tests/install.bats tests/doctor.bats tests/fakes
git commit -m "feat: idempotent installer, backups, doctor and uninstaller"
```

---

### Task 7: Documentation, agent contract, skill

**Files:**
- Create: `README.md`, `AGENTS.md`, `docs/INSTALL.md`, `docs/REMOTE.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `skills/nekoshell/SKILL.md`, `tests/docs.bats`
- Modify: `.github/workflows/check.yml` (run `tests/docs.bats` is already covered by `bats tests`)

**Interfaces:**
- Consumes: the real flags and commands from Tasks 4 to 6 (`install.sh --yes`, `nekoshell-doctor --json`, `nekoshell-art add`, `spotify_player authenticate`, `install.sh --iterm-prefs`).
- Produces: docs only.

- [ ] **Step 1: Write the failing test**

`tests/docs.bats`:
```bash
#!/usr/bin/env bats
load helpers

@test "every documented command exists" {
  for f in README.md AGENTS.md docs/INSTALL.md docs/REMOTE.md skills/nekoshell/SKILL.md; do
    [ -f "$REPO_ROOT/$f" ]
  done
  grep -q -- '--yes' "$REPO_ROOT/AGENTS.md"
  grep -q 'nekoshell-doctor' "$REPO_ROOT/AGENTS.md"
  grep -q 'spotify_player authenticate' "$REPO_ROOT/AGENTS.md"
  grep -q -- '--iterm-prefs' "$REPO_ROOT/AGENTS.md"
  grep -q 'backup' "$REPO_ROOT/AGENTS.md"
  grep -q 'NEKOSHELL_GREET_SSH' "$REPO_ROOT/docs/REMOTE.md"
  grep -q -- '--skip-spotify' "$REPO_ROOT/docs/REMOTE.md"
  grep -q '^name: nekoshell' "$REPO_ROOT/skills/nekoshell/SKILL.md"
  grep -q '^description:' "$REPO_ROOT/skills/nekoshell/SKILL.md"
}

@test "changelog has a v0.1.0 entry" {
  grep -q '0.1.0' "$REPO_ROOT/CHANGELOG.md"
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/docs.bats`
Expected: FAIL (README.md missing).

- [ ] **Step 3: Write the docs**

Write these with the following required content. Use sentence case headings, straight quotes, no em dashes, no emoji in headings.

`README.md`:
- One-line description (the repo description on GitHub).
- Two image links: `docs/screenshots/greeting.png` and `docs/screenshots/panel.png` (files are added in Task 8; reference them now).
- "What you get": look (Catppuccin Mocha, JetBrainsMono Nerd Font, Starship, eza, bat, fzf, zoxide, delta, btop, lazygit), greeting (Pokémon via pokemon-colorscripts 70 percent, your art pack 30 percent, machine stats via fastfetch, under 150 ms, never inside tmux, SSH, or Claude Code), panel (⌥M anywhere, iTerm2 hotkey window docked right, spotify_player, Premium required, shpotify remote fallback).
- "Install" in three commands:
  ```
  git clone https://github.com/0PrashantYadav0/nekoshell.git ~/.nekoshell
  cd ~/.nekoshell
  ./install.sh
  ```
  then the human steps (restart iTerm2, `spotify_player authenticate`, press ⌥M), then `nekoshell-doctor`.
- "Install with an AI agent": paste this into your agent: "Install https://github.com/0PrashantYadav0/nekoshell on this Mac by following its AGENTS.md" and, for agents that support skills, `npx skills add 0PrashantYadav0/nekoshell`.
- "Customise": `~/.config/nekoshell/zsh/local.zsh` for your aliases, `~/.config/nekoshell/greet.conf` for the greeting mix, `nekoshell-art add` for images, the hotkey is `HotKey Key Code`/`HotKey Modifier Flags` in `iterm2/build-profiles.py`.
- "Uninstall": `./uninstall.sh`.
- Links: docs/INSTALL.md, docs/REMOTE.md, AGENTS.md, CONTRIBUTING.md, CHANGELOG.md. Credits: Catppuccin, pokemon-colorscripts (sprites from PokéSprite, Pokémon is a trademark of The Pokémon Company), fastfetch, spotify_player, Starship, iTerm2.

`AGENTS.md` (the contract; write it as instructions to the agent, imperative):
1. Preconditions, each with its check command: macOS (`uname -s` = Darwin), Homebrew (`command -v brew`), iTerm2 (`ls /Applications/iTerm.app`), zsh (`zsh --version`). If Homebrew is missing, stop and hand the human the official install command; do not run it yourself.
2. Where to run from: a terminal that is not iTerm2 (Terminal.app, or the Claude Code desktop app) so iTerm2 can be quit for the global prefs step. If that is impossible, run anyway and expect the prefs step to be reported as pending.
3. Install: `[ -d ~/.nekoshell ] || git clone https://github.com/0PrashantYadav0/nekoshell.git ~/.nekoshell; cd ~/.nekoshell && git pull --ff-only && ./install.sh --yes`. Re-running is safe. Use `--skip-spotify` on machines without Spotify.
4. Verify: `bin/nekoshell-doctor --json`. Success is exit code 0. `warn` rows are acceptable only for `spotify` (needs the human to log in) and `iterm2 prefs` (needs iTerm2 quit). Any `fail` row means the install is not done: read its detail and fix that, then re-run the doctor.
5. Hand these to the human, verbatim, and stop: (a) quit and reopen iTerm2; (b) if the doctor said prefs are pending, with iTerm2 closed run `~/.nekoshell/install.sh --iterm-prefs` from Terminal.app; (c) run `spotify_player authenticate` (opens a browser, Premium required); (d) press ⌥M.
6. What the installer changed and where the originals are: `~/.local/share/nekoshell/backup/<timestamp>/` with `manifest.txt`. Never delete that directory. To undo everything: `./uninstall.sh --yes`.
7. Rules: do not edit files under `~/.config/nekoshell/` except `zsh/local.zsh` and `greet.conf`; do not run `defaults write` for iTerm2 while iTerm2 is running; do not install pokemon-colorscripts with sudo; do not commit to this repo on the user's behalf.

`docs/INSTALL.md`: the same steps for a human with explanations, the "why Terminal.app" note, what each step does, how to pick the profile manually in iTerm2 (Settings, Profiles, select nekoshell, Other Actions, Set as Default), troubleshooting (icons look wrong: font not selected; greeting missing: run `nekoshell-greet` and `nekoshell-doctor`; panel does not open: check iTerm2 Settings, Keys, Hotkey Window shows ⌥M).

`docs/REMOTE.md`: what carries to SSH hosts, Codespaces and devcontainers (zsh config, Starship, aliases, bat/eza/fzf/zoxide if installed with Linuxbrew, the greeting when `NEKOSHELL_GREET_SSH=1` and fastfetch plus pokemon-colorscripts are installed), what does not (fonts, the iTerm2 panel, Spotify), and the invocation `./install.sh --yes --skip-spotify` (note: v0.1 targets macOS; on Linux the installer refuses, so copy `stow/config/.config/starship.toml` and `stow/config/.config/nekoshell/zsh/*.zsh` by hand and source them). Codespaces: point `dotfiles` at the repo and use `install.sh` only after Linux support lands; for now a `remote/bootstrap.sh` is not shipped.

`CONTRIBUTING.md`: run `brew install bats-core shellcheck`, `bats tests`, `shellcheck -x install.sh uninstall.sh lib/*.sh bin/*`, conventional commits, keep scripts bash 3.2 compatible, no copyrighted images, vendored files go in `THIRD_PARTY.md`.

`CHANGELOG.md`: `## 0.1.0 (unreleased)` with one bullet per feature area.

`skills/nekoshell/SKILL.md`:
```markdown
---
name: nekoshell
description: Install the nekoshell terminal rig (Catppuccin iTerm2 look, Pokémon greeting with machine stats, hotkey Spotify panel) on a Mac by running its installer and doctor, then handing the human the steps only they can do.
---

# nekoshell

Follow `AGENTS.md` in https://github.com/0PrashantYadav0/nekoshell exactly. In short:

1. Check preconditions: macOS, Homebrew, iTerm2, zsh.
2. `[ -d ~/.nekoshell ] || git clone https://github.com/0PrashantYadav0/nekoshell.git ~/.nekoshell; cd ~/.nekoshell && git pull --ff-only && ./install.sh --yes`
3. `bin/nekoshell-doctor --json`; exit 0 with only `spotify` and `iterm2 prefs` warns is success.
4. Tell the human: restart iTerm2, run `spotify_player authenticate`, press ⌥M. If prefs are pending, they run `install.sh --iterm-prefs` with iTerm2 closed.

Never delete `~/.local/share/nekoshell/backup/`. Undo with `./uninstall.sh --yes`.
```

- [ ] **Step 4: Run the tests**

Run: `bats tests/docs.bats`
Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add README.md AGENTS.md docs CONTRIBUTING.md CHANGELOG.md skills tests/docs.bats
git commit -m "docs: README, agent contract, install and remote guides, skill"
```

---

### Task 8: Install on this Mac, verify, capture screenshots, pin the window type

This task runs against the real machine of the repo owner (the controller's user has approved this). It is the prototype ticket 0011 from the Wayfinder map.

**Files:**
- Create: `docs/screenshots/greeting.png`, `docs/screenshots/panel.png`
- Modify: `lib/iterm.sh` and `iterm2/build-profiles.py` default `--window-type` if 6 turns out wrong; `tests/iterm_profiles.bats` if the default changes; `CHANGELOG.md`

**Interfaces:**
- Consumes: everything.
- Produces: a verified install and the two screenshots the README links to.

- [ ] **Step 1: Run the installer for real**

Run from the repo root: `./install.sh --yes`
Expected: exit 0. Steps 1 to 10 print `ok` except step 10, which prints the pending warning because this runs inside iTerm2. Record the backup directory path in your report.

- [ ] **Step 2: Run the doctor**

Run: `bin/nekoshell-doctor`
Expected: no `fail` rows. `warn` for `iterm2 prefs` and possibly `spotify`. If any `fail` appears, fix the cause in the repo (not by hand-editing the home directory), add or adjust a test, commit, and re-run.

- [ ] **Step 3: Verify the greeting in a real iTerm2 window**

Run: `osascript -e 'tell application "iTerm2" to create window with profile "nekoshell"'`, wait 2 seconds, then `screencapture -x docs/screenshots/greeting.png` of that window (use `osascript` to get the window id, or capture the front window with `screencapture -l <windowid>`; `-l` takes the CGWindowID from `osascript -e 'tell application "iTerm2" to id of front window'`). Read the PNG with the Read tool and confirm a Pokémon (or art) and the stats are visible. If the font shows boxes, the Nerd Font is not being picked up: check the font PostScript name with `fc-list | grep -i jetbrainsmono` and fix `FONT` in `iterm2/build-profiles.py`, re-run `install.sh --yes`, and repeat.

- [ ] **Step 4: Verify the panel and pin the window type**

Press the hotkey is not possible from a script; instead: `osascript -e 'tell application "iTerm2" to create window with profile "nekoshell panel"'` and capture it. Then check the docking by reading iTerm2's view of the profile: `python3 -c "import json;p=json.load(open('$HOME/Library/Application Support/iTerm2/DynamicProfiles/nekoshell.json'))['Profiles'][1];print(p['Window Type'])"` prints what we wrote; the real test is visual. If the window is not docked to the right edge, try the other candidate values in order (10, 5, 9, 2, 4) by running `NEKOSHELL_PANEL_WINDOW_TYPE=N ./install.sh --yes --skip-brew` and re-creating the window, until it docks right. Then set that number as the default in `iterm2/build-profiles.py` (`--window-type` default), in `lib/iterm.sh` (`NEKOSHELL_PANEL_WINDOW_TYPE`), and in `tests/iterm_profiles.bats` (both the flag and the expected value), and note the verified value in the CHANGELOG. Capture `docs/screenshots/panel.png` showing the main window with the panel open on the right (open the panel via the profile, then `screencapture -x` the whole screen and crop is acceptable).

- [ ] **Step 5: Run the full suite and commit**

Run: `bats tests && shellcheck -x install.sh uninstall.sh lib/*.sh bin/*`
Expected: all pass.

```bash
git add docs/screenshots iterm2/build-profiles.py lib/iterm.sh tests/iterm_profiles.bats CHANGELOG.md
git commit -m "feat: verified install on macOS 26, screenshots, pinned panel window type"
```

- [ ] **Step 6: Report**

Report the backup path, the doctor output, the verified window type number, and anything that needed a code change. Leave iTerm2's global prefs pending (the human applies them from Terminal.app); say so.

---

## Self-review (done by the plan author)

- Spec coverage: look (Tasks 2, 3), greeting (4), panel (2, 5), installer/doctor/uninstall (6), docs and skill (7), verification and screenshots (8), CI and license (1). Free-tier remote (5). Alias migration (3, 6). Backups (6). `--check`, `--dry-run`, `--iterm-prefs` (6). Art pack samples and README (4).
- Placeholder scan: none. Every step has its content.
- Consistency: `NEKOSHELL_CONFIG`, `NEKOSHELL_CACHE`, `ITERM_DYNAMIC_DIR` defined in Task 1 and used unchanged after. Guids identical in Task 2 generator, `lib/iterm.sh`, tests and doctor. `nekoshell-music` path in the panel Command matches `bin/nekoshell-music`. Fake `fastfetch` and `pokemon-colorscripts` interfaces match the greet script's calls. `deps.lock` key `pokemon-colorscripts=` matches the `sed` in `install.sh`.

---

## Tasks added after the first build (owner requests, 2026-09-11)

### Task 9: Pokémon facts line in the greeting

Requested by the owner after the plan was written: "include short info about the Pokémon you added". The greeting's `Art` row currently shows only the Pokémon's name (plus ` ✦ shiny`). It should show a short facts line: capitalised name, national dex number, type(s), generation. Facts only: no Pokédex flavour text (that text is copyrighted by Nintendo/Game Freak); numbers, types and generations are facts and are fine.

**Files:**
- Create: `scripts/gen-pokemon-data.py`, `data/pokemon.tsv`, `tests/pokemon_data.bats`
- Modify: `bin/nekoshell-greet` (build the facts line), `tests/greet.bats` (expected `art-name` values), `THIRD_PARTY.md` (PokéAPI data row), `README.md` (one sentence under the greeting description), `CHANGELOG.md` (one bullet)

**Interfaces:**
- Consumes: `bin/nekoshell-greet`'s `show_pokemon` (name is the first line of pokemon-colorscripts output; the cache file is `$NEKOSHELL_CACHE/art-name`); `NEKOSHELL_ROOT` (now set from the script's own location, per the final-review fix).
- Produces: `data/pokemon.tsv` with a header row and tab-separated columns `name	dex	types	gen	height_m	weight_kg`, one row per species, `name` being the PokéAPI species identifier (lowercase, hyphenated: `pikachu`, `mr-mime`, `nidoran-f`), which is the naming pokemon-colorscripts uses. `types` is slash-joined and capitalised (`Grass/Poison`). A shell function `pokemon_facts NAME` in `bin/nekoshell-greet` that prints `Pikachu · #025 · Electric · Gen 1` for a known name and `Pikachu` (just the capitalised name) for an unknown one.

- [ ] **Step 1: Write the data generator and run it once**

`scripts/gen-pokemon-data.py` (stdlib only):
- Downloads four CSVs from the PokeAPI/pokeapi repository at a pinned commit (record the 40-char sha you used in the script's docstring and in THIRD_PARTY.md): `data/v2/csv/pokemon_species.csv` (id, identifier, generation_id), `data/v2/csv/pokemon.csv` (id, identifier, species_id, height, weight, is_default), `data/v2/csv/pokemon_types.csv` (pokemon_id, type_id, slot), `data/v2/csv/types.csv` (id, identifier). URL shape: `https://raw.githubusercontent.com/PokeAPI/pokeapi/<sha>/data/v2/csv/<file>`.
- For each species: dex = species id; types = the default pokemon (`is_default == 1`, or `pokemon.id == species.id`) types ordered by slot, capitalised; gen = generation_id; height_m = height/10; weight_kg = weight/10 (one decimal each).
- Writes `data/pokemon.tsv` sorted by dex with the header above. Prints the row count.
- Run it: `python3 scripts/gen-pokemon-data.py` and commit the TSV (expect roughly 1000 to 1100 rows; pokemon-colorscripts covers generations 1 to 8, extra rows are harmless).

- [ ] **Step 2: Write the failing tests**

`tests/pokemon_data.bats`:
```bash
#!/usr/bin/env bats
load helpers

@test "pokemon.tsv has the header and well-known rows" {
  run head -1 "$REPO_ROOT/data/pokemon.tsv"
  [ "$output" = $'name\tdex\ttypes\tgen\theight_m\tweight_kg' ]
  run awk -F'\t' '$1=="pikachu"{print $2, $3, $4}' "$REPO_ROOT/data/pokemon.tsv"
  [ "$output" = "25 Electric 1" ]
  run awk -F'\t' '$1=="bulbasaur"{print $2, $3, $4}' "$REPO_ROOT/data/pokemon.tsv"
  [ "$output" = "1 Grass/Poison 1" ]
  run awk -F'\t' '$1=="mr-mime"{print $2}' "$REPO_ROOT/data/pokemon.tsv"
  [ "$output" = "122" ]
  run bash -c "wc -l < '$REPO_ROOT/data/pokemon.tsv' | tr -d ' '"
  [ "$output" -gt 900 ]
}

@test "pokemon_facts formats a known and an unknown name" {
  run bash -c "NEKOSHELL_ROOT='$REPO_ROOT'; source <(sed -n '/^pokemon_facts()/,/^}/p' '$REPO_ROOT/bin/nekoshell-greet'); pokemon_facts pikachu; pokemon_facts missingno"
  [ "${lines[0]}" = "Pikachu · #025 · Electric · Gen 1" ]
  [ "${lines[1]}" = "Missingno" ]
}
```

In `tests/greet.bats`, update the two assertions on the cache file: the Pokémon path now expects `Pikachu · #025 · Electric · Gen 1`, and the shiny test expects `Pikachu (shiny) · ...`? No: the fake prints `pikachu (shiny)` as the name when `-s` is passed, which is fake-only behaviour. Change the fake `tests/fakes/pokemon-colorscripts` to always print `pikachu` as the name (real pokemon-colorscripts prints the plain name; shininess is only in the colours), and expect `Pikachu · #025 · Electric · Gen 1 ✦ shiny` in the shiny test.

- [ ] **Step 3: Run the tests to verify they fail**

Run: `bats tests/pokemon_data.bats tests/greet.bats`
Expected: FAIL (no TSV / no `pokemon_facts`).

- [ ] **Step 4: Implement `pokemon_facts` in bin/nekoshell-greet**

Add above `show_pokemon`:
```bash
# pokemon_facts NAME: "Pikachu · #025 · Electric · Gen 1", or just the capitalised name if unknown.
pokemon_facts() {
  local name="$1" tsv="$NEKOSHELL_ROOT/data/pokemon.tsv" cap
  cap="$(printf '%s' "${name:0:1}" | tr '[:lower:]' '[:upper:]')${name:1}"
  if [[ -r "$tsv" ]]; then
    awk -F'\t' -v n="$name" -v cap="$cap" '$1==n {printf "%s · #%03d · %s · Gen %s\n", cap, $2, $3, $4; found=1} END {if (!found) print cap}' "$tsv"
  else
    printf '%s\n' "$cap"
  fi
}
```
In `show_pokemon`, write `"$(pokemon_facts "$name")$shiny"` to the cache file instead of `"$name$shiny"`. Keep the name lookup tolerant: pokemon-colorscripts prints the name exactly as its file is named (lowercase, hyphens), so pass it through unchanged.

- [ ] **Step 5: Run the tests, shellcheck, and the greeting for real**

Run: `bats tests && shellcheck -x bin/nekoshell-greet`. Then, since the rig is installed on this machine: `NEKOSHELL_SEED=7 NEKOSHELL_NO_GREET= CLAUDECODE= TMUX= script -q /dev/null bin/nekoshell-greet </dev/null | tail -c 400; cat ~/.cache/nekoshell/art-name` and confirm a real facts line appears (a real Pokémon name from pokemon-colorscripts resolves in the TSV). Try three seeds; if any real name fails to resolve, note it in the report (a naming mismatch between pokemon-colorscripts and PokéAPI) and add a small alias map in `pokemon_facts` only for the mismatches you actually observed.

- [ ] **Step 6: Docs and third-party record**

`THIRD_PARTY.md`: row `data/pokemon.tsv | generated from PokeAPI/pokeapi CSVs at <sha> | BSD-3-Clause (data); Pokémon names and types are trademarks of The Pokémon Company`. README, under the greeting bullet: "The Art line shows the Pokémon's name, national dex number, type and generation." CHANGELOG 0.1.0: one bullet.

- [ ] **Step 7: Commit**

```bash
git add scripts/gen-pokemon-data.py data/pokemon.tsv bin/nekoshell-greet tests/pokemon_data.bats tests/greet.bats tests/fakes/pokemon-colorscripts THIRD_PARTY.md README.md CHANGELOG.md
git commit -m "feat: show dex number, type and generation beside the Pokémon in the greeting"
```

---

### Task 10: Greeting v2 (storage, Wi-Fi, IP, battery) and the two-line information prompt

Requested by the owner mid-run. Two parts, one commit.

**Files:**
- Modify: `stow/config/.config/fastfetch/config.jsonc`, `stow/config/.config/starship.toml`, `tests/zsh_stack.bats` (starship assertions), `tests/greet.bats` (only if a fastfetch fake assertion depends on the module list), `README.md` (greeting and prompt descriptions), `docs/INSTALL.md` (troubleshooting entry for the Wi-Fi row), `CHANGELOG.md`
- Create: `tests/fastfetch_config.bats`

**Interfaces:**
- Consumes: fastfetch 2.68 is installed on this machine; run `fastfetch --list-modules` and `fastfetch --help <module>-format` to confirm module names and options before editing. Starship 1.26 is installed; `starship print-config` validates the TOML. The greeting script passes the config with `--config`; nothing else changes there.
- Produces: the greeting rows and the prompt layout below. Nothing downstream depends on the exact rows.

- [ ] **Step 1: Write the failing test**

`tests/fastfetch_config.bats`:
```bash
#!/usr/bin/env bats
load helpers

CFG="$REPO_ROOT/stow/config/.config/fastfetch/config.jsonc"

strip_jsonc() { sed -e 's://[^"]*$::' "$CFG"; }

@test "fastfetch config is valid JSONC with the expected rows in order" {
  run bash -c "sed -e 's://[^\"]*\$::' '$CFG' | python3 -c '
import json,sys
d=json.load(sys.stdin)
rows=[m if isinstance(m,str) else m[\"type\"] for m in d[\"modules\"]]
print(\" \".join(rows))
print(d[\"display\"][\"color\"][\"keys\"])'"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "title separator os host uptime shell terminal cpu memory disk battery wifi localip packages command break colors" ]
  [ "${lines[1]}" = "38;2;203;166;247" ]
}

@test "fastfetch accepts the config" {
  command -v fastfetch >/dev/null || skip "fastfetch not installed"
  run fastfetch --config "$CFG" --logo none --pipe
  [ "$status" -eq 0 ]
  [[ "$output" == *"Storage"* ]]
  [[ "$output" == *"Packages"* ]]
}
```

Starship assertions to add to `tests/zsh_stack.bats` (the existing starship test stays):
```bash
@test "starship prompt is two lines with a full-path directory and a right-aligned clock" {
  run python3 -c "
import tomllib
d=tomllib.load(open('$REPO_ROOT/stow/config/.config/starship.toml','rb'))
print(d['directory']['truncation_length'], d['directory']['truncate_to_repo'])
print('\$fill' in d['format'], '\$time' in d['format'], '\$status' in d['format'], '\$line_break' in d['format'], d['format'].rstrip().endswith('\$character'))
print(d['time']['disabled'], d['status']['disabled'])"
  [ "${lines[0]}" = "0 False" ]
  [ "${lines[1]}" = "True True True True True" ]
  [ "${lines[2]}" = "False False" ]
}

@test "starship validates its own config" {
  command -v starship >/dev/null || skip "starship not installed"
  run env STARSHIP_CONFIG="$REPO_ROOT/stow/config/.config/starship.toml" starship print-config
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bats tests/fastfetch_config.bats tests/zsh_stack.bats`
Expected: the new tests FAIL (row list differs; no `$fill`).

- [ ] **Step 3: Rewrite the fastfetch config**

Replace the `modules` array in `stow/config/.config/fastfetch/config.jsonc` with, in this order (keep `display` as is):
```jsonc
"modules": [
  "title",
  "separator",
  { "type": "os", "key": "OS" },
  { "type": "host", "key": "Host" },
  { "type": "uptime", "key": "Uptime" },
  { "type": "shell", "key": "Shell" },
  { "type": "terminal", "key": "Terminal" },
  { "type": "cpu", "key": "CPU" },
  { "type": "memory", "key": "Memory" },
  { "type": "disk", "key": "Storage", "folders": "/" },
  { "type": "battery", "key": "Battery" },
  { "type": "wifi", "key": "Wi-Fi" },
  { "type": "localip", "key": "IP", "showIpv6": false, "compact": true },
  { "type": "packages", "key": "Packages" },
  { "type": "command", "key": "Art", "text": "cat \"$HOME/.cache/nekoshell/art-name\" 2>/dev/null" },
  "break",
  "colors"
]
```
Rows dropped on purpose: Kernel (redundant with OS on macOS) and Terminal Font (one-time check, the doctor covers the font). If `fastfetch --list-modules` names an option differently (for example `folders` vs `folder`, or the `wifi` module reports the SSID as `<redacted>` on macOS 26 because Location Services permission is required), keep the module and note it in `docs/INSTALL.md` troubleshooting: "Wi-Fi shows `<redacted>` or is missing: give iTerm2 Location Services access in System Settings, Privacy and Security, Location Services". Run `fastfetch --config <file>` on this machine and read the output to confirm every row renders.

- [ ] **Step 4: Rewrite the Starship prompt**

Replace `stow/config/.config/starship.toml` with a two-line prompt. Keep the palette table exactly as it is and keep `palette = "catppuccin_mocha"`. New layout:
```toml
"$schema" = 'https://starship.rs/config-schema.json'
add_newline = true
palette = "catppuccin_mocha"

format = """
$directory$git_branch$git_status$git_state$nodejs$python$rust$golang$docker_context$fill$cmd_duration$status$jobs$time
$line_break$character"""

[directory]
style = "bold blue"
truncation_length = 0
truncate_to_repo = false
home_symbol = "~"
read_only = " 󰌾"
format = "[$path]($style)[$read_only]($read_only_style) "

[fill]
symbol = " "

[time]
disabled = false
style = "overlay0"
format = "[$time]($style)"
time_format = "%H:%M"

[status]
disabled = false
style = "red"
symbol = "✘ "
format = "[$symbol$status]($style) "

[jobs]
symbol = " "
style = "peach"
format = "[$symbol$number]($style) "

[git_state]
style = "yellow"
format = "[$state( $progress_current/$progress_total)]($style) "

[docker_context]
symbol = " "
style = "sky"
format = "[$symbol$context]($style) "
```
plus the existing `[git_branch]`, `[git_status]`, `[cmd_duration]`, `[character]`, `[nodejs]`, `[python]`, `[rust]`, `[golang]` tables unchanged (keep `cmd_duration` `min_time = 2000`). `truncation_length = 0` shows the full path; `home_symbol` keeps it readable. Validate with `starship print-config`.

- [ ] **Step 5: Run the tests and look at the real prompt**

Run: `bats tests`. Then in this checkout: `STARSHIP_CONFIG=stow/config/.config/starship.toml starship prompt --status=1 --cmd-duration=3500 --jobs=1 | cat -v | head -3` and confirm line 1 has the full path on the left and the time on the right, line 2 has the character. Paste that output in the report.

- [ ] **Step 6: Docs and commit**

README (greeting bullet): rows now shown; (new "Prompt" bullet): "Above every command: the full working directory, git branch and status, language versions when inside a project, and on the right the last command's duration, exit status and the clock." CHANGELOG bullet. Commit:
```bash
git add stow/config/.config/fastfetch/config.jsonc stow/config/.config/starship.toml tests/fastfetch_config.bats tests/zsh_stack.bats README.md docs/INSTALL.md CHANGELOG.md
git commit -m "feat: storage, Wi-Fi, IP and battery in the greeting; two-line information prompt"
```

---

### Task 11: Catppuccin flavours and the `nekoshell-theme` command

Requested by the owner mid-run ("configure the colour theme as well"). All four Catppuccin flavours (latte, frappe, macchiato, mocha) become selectable with one command; mocha stays the default. Everything that carries colour is regenerated from one palette file.

**Files:**
- Create: `scripts/gen-palettes.py`, `data/palettes.json`, `bin/nekoshell-theme`, `templates/starship.toml` (moved from stow, see below), `templates/fastfetch.jsonc` (moved from stow), `stow/config/.config/bat/themes/Catppuccin Latte.tmTheme`, `... Frappe.tmTheme`, `... Macchiato.tmTheme`, `stow/config/.config/btop/themes/catppuccin_latte.theme`, `..._frappe.theme`, `..._macchiato.theme`, `tests/theme.bats`
- Modify: `iterm2/build-profiles.py` (`--flavor`, palette from `data/palettes.json`), `lib/iterm.sh` (pass the flavour), `install.sh` (render starship and fastfetch configs from templates; default flavour), `stow/config/.config/nekoshell/zsh/env.zsh` (source `~/.config/nekoshell/theme.zsh`), `bin/nekoshell-doctor` (a `theme` row), `THIRD_PARTY.md`, `README.md`, `docs/INSTALL.md`, `AGENTS.md` (theme.zsh, starship.toml and fastfetch config are now user files), `CHANGELOG.md`, `tests/iterm_profiles.bats`, `tests/install.bats`, `tests/zsh_stack.bats`, `tests/fastfetch_config.bats` (paths)
- Delete from stow: `stow/config/.config/starship.toml`, `stow/config/.config/fastfetch/config.jsonc` (they become rendered user files, like `greet.conf`)

**Interfaces:**
- Consumes: `iterm2/build-profiles.py` (`MOCHA` dict and `ANSI` list), `install.sh` step 4 (template copy pattern from `greet.conf`), `lib/iterm.sh` `iterm_write_profiles`, `bin/nekoshell-greet` (`--config "$HOME/.config/fastfetch/config.jsonc"`, unchanged path), Starship (`palette` key), bat (`--theme` name), btop (`color_theme`), fzf (`FZF_DEFAULT_OPTS`).
- Produces: `data/palettes.json`: `{"mocha": {"base": "1e1e2e", ...26 names...}, "macchiato": {...}, "frappe": {...}, "latte": {...}}` (lowercase hex without `#`, the same 26 role names Catppuccin uses). `bin/nekoshell-theme <flavour>|current|list`. The current flavour is stored in `~/.config/nekoshell/theme` (one word). `~/.config/nekoshell/theme.zsh` exports `BAT_THEME`, `FZF_DEFAULT_OPTS`, `NEKOSHELL_THEME`. Rendered user files: `~/.config/starship.toml`, `~/.config/fastfetch/config.jsonc`.

- [ ] **Step 1: Generate the palette file**

`scripts/gen-palettes.py`: downloads `palette.json` from the catppuccin/palette repository at a pinned commit (`https://raw.githubusercontent.com/catppuccin/palette/<sha>/palette.json`; record the sha in the docstring and THIRD_PARTY.md), extracts for each flavour the 26 colours' `hex` values (strip `#`), and writes `data/palettes.json` sorted by flavour. Run it and commit the output. Sanity: `mocha.base == "1e1e2e"`, `latte.base == "eff1f5"`.

Also download the three missing bat themes from catppuccin/bat and the three btop themes from catppuccin/btop at the commits already recorded in THIRD_PARTY.md, and add rows for them.

- [ ] **Step 2: Write the failing tests**

`tests/theme.bats`:
```bash
#!/usr/bin/env bats
load helpers

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_SKIP_PREFLIGHT=1
  "$REPO_ROOT/install.sh" --yes >/dev/null
}
teardown() { teardown_tmp_home; }

@test "palettes.json has four flavours with the known bases" {
  run python3 -c "
import json; d=json.load(open('$REPO_ROOT/data/palettes.json'))
print(sorted(d)); print(d['mocha']['base'], d['latte']['base'], len(d['mocha']))"
  [ "${lines[0]}" = "['frappe', 'latte', 'macchiato', 'mocha']" ]
  [ "${lines[1]}" = "1e1e2e eff1f5 26" ]
}

@test "install renders mocha by default" {
  [ "$(cat "$HOME/.config/nekoshell/theme")" = "mocha" ]
  [ ! -L "$HOME/.config/starship.toml" ]
  grep -q '^palette = "catppuccin_mocha"' "$HOME/.config/starship.toml"
  grep -q '38;2;203;166;247' "$HOME/.config/fastfetch/config.jsonc"
  grep -q 'BAT_THEME="Catppuccin Mocha"' "$HOME/.config/nekoshell/theme.zsh"
}

@test "nekoshell-theme latte re-renders every themed file" {
  run "$REPO_ROOT/bin/nekoshell-theme" latte
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.config/nekoshell/theme")" = "latte" ]
  grep -q '^palette = "catppuccin_latte"' "$HOME/.config/starship.toml"
  grep -q 'BAT_THEME="Catppuccin Latte"' "$HOME/.config/nekoshell/theme.zsh"
  grep -q 'color_theme = "catppuccin_latte"' "$HOME/.config/btop/btop.conf"
  run python3 -c "
import json; p=json.load(open('$HOME/Library/Application Support/iTerm2/DynamicProfiles/nekoshell.json'))['Profiles'][0]
bg=p['Background Color']; print(round(bg['Red Component']*255), round(bg['Green Component']*255), round(bg['Blue Component']*255))"
  [ "$output" = "239 241 245" ]
}

@test "nekoshell-theme rejects unknown flavours and lists the known ones" {
  run "$REPO_ROOT/bin/nekoshell-theme" dracula
  [ "$status" -ne 0 ]
  run "$REPO_ROOT/bin/nekoshell-theme" list
  [ "$output" = $'frappe\nlatte\nmacchiato\nmocha' ]
  run "$REPO_ROOT/bin/nekoshell-theme" current
  [ "$output" = "mocha" ]
}

@test "a user edit to starship.toml survives a re-install but not a theme switch" {
  echo '# mine' >> "$HOME/.config/starship.toml"
  "$REPO_ROOT/install.sh" --yes >/dev/null
  grep -q '# mine' "$HOME/.config/starship.toml"
  "$REPO_ROOT/bin/nekoshell-theme" mocha >/dev/null
  ! grep -q '# mine' "$HOME/.config/starship.toml"
}
```
Update `tests/iterm_profiles.bats`: add a case `--flavor latte` expecting background `239 241 245`; the existing mocha assertions stay (mocha is the default). Update `tests/zsh_stack.bats` and `tests/fastfetch_config.bats` to read the templates (`templates/starship.toml`, `templates/fastfetch.jsonc`) instead of the stow paths, and `tests/install.bats` if it asserted `~/.config/starship.toml` was a symlink (it is now a rendered file; the backup test's pre-existing `starship.toml` must still be backed up).

- [ ] **Step 3: Run the tests to verify they fail**

Run: `bats tests/theme.bats`
Expected: FAIL.

- [ ] **Step 4: Implement**

1. `iterm2/build-profiles.py`: load `data/palettes.json` relative to the script; add `--flavor` (default `mocha`); `MOCHA` becomes `PALETTE = palettes[flavor]`; the ANSI mapping and roles stay the same names. For `latte` the cursor guide and selection still use `surface0`/`surface2` from that flavour, which is correct.
2. `templates/starship.toml`: the Task 10 file with FOUR palette tables (`[palettes.catppuccin_latte]` and so on, values from `data/palettes.json` with `#` prefix) and the line `palette = "catppuccin_@@FLAVOR@@"`. `templates/fastfetch.jsonc`: the Task 10 file with `"keys": "@@KEYS_SGR@@"` and `"title": "@@TITLE_SGR@@"` where the renderer substitutes `38;2;R;G;B` of `mauve` and `blue` for the flavour.
3. `lib/theme.sh` (new, sourced by install.sh and nekoshell-theme): `theme_render FLAVOR` writes `~/.config/nekoshell/theme`, `~/.config/nekoshell/theme.zsh` (BAT_THEME `Catppuccin <Flavour>` with the first letter capitalised, FZF_DEFAULT_OPTS built from the flavour's `surface0`, `base`, `rosewater`, `red`, `text`, `mauve`, `lavender`, `surface1` the same way env.zsh does today, `NEKOSHELL_THEME`), `~/.config/starship.toml` and `~/.config/fastfetch/config.jsonc` from the templates, `~/.config/btop/btop.conf` with `color_theme = "catppuccin_<flavor>"` (write the file if absent, else replace that one line with sed), then calls `iterm_write_profiles` with `--flavor`. Use `python3` for the substitutions if that is simpler than sed (it is available on macOS). `FZF_DEFAULT_OPTS` and `BAT_THEME` move OUT of `env.zsh`, which instead does `[[ -r "$NEKOSHELL_CONFIG/theme.zsh" ]] && source "$NEKOSHELL_CONFIG/theme.zsh"`.
4. `install.sh`: step 4 sets the flavour to the existing `~/.config/nekoshell/theme` if present else `mocha`; renders starship.toml and fastfetch config only if they do not exist (like greet.conf), and always renders `theme.zsh` and the iTerm2 profile (step 9 now passes the flavour). The stow package no longer contains starship.toml or fastfetch/config.jsonc, so the backup derivation drops them automatically; add both to the backup list explicitly (they are still files the installer replaces on first install).
5. `bin/nekoshell-theme`: `set -euo pipefail`; sets `NEKOSHELL_ROOT` from its own location; subcommands `list`, `current`, `<flavour>`; the flavour path calls `theme_render` and prints "theme: <flavour>. Open a new terminal window for the prompt and greeting; iTerm2 reloads the profile colours on its own."
6. `bin/nekoshell-doctor`: add a `theme` row: `ok` with the flavour when `~/.config/nekoshell/theme` names a known flavour and `theme.zsh` exists, else `warn "run nekoshell-theme mocha"`.

- [ ] **Step 5: Run everything**

Run: `bats tests && shellcheck -x install.sh uninstall.sh lib/*.sh bin/* && zsh -n stow/zsh/.zshrc && STARSHIP_CONFIG=templates/starship.toml starship print-config >/dev/null` (the template has `@@FLAVOR@@` in the palette line; if `print-config` rejects it, render to a temp file with mocha first and validate that).

- [ ] **Step 6: Docs and commit**

README "Customise": `nekoshell-theme latte` (and list). docs/INSTALL.md: a "Themes" section. AGENTS.md: the user-file list now includes `theme`, `theme.zsh`, `starship.toml`, `fastfetch/config.jsonc`. THIRD_PARTY.md rows (palette.json, six theme files). CHANGELOG bullet. Commit:
```bash
git add -A
git commit -m "feat: all four Catppuccin flavours with nekoshell-theme"
```

---

### Task 12: Polish set (fzf previews, themed highlighting, atuin, iTerm2 status bar)

Requested by the owner mid-run: "find what changes make it aesthetic and beautiful, which makes it functional as well". The controller fixed this list so the task is bounded. Each item is functional first.

**Files:**
- Modify: `Brewfile` (add `atuin`), `stow/config/.config/nekoshell/zsh/env.zsh`, `stow/config/.config/nekoshell/zsh/plugins.txt`, `stow/zsh/.zshrc`, `iterm2/build-profiles.py` (status bar layout, cursor guide, dim inactive panes), `lib/theme.sh` (zsh-syntax-highlighting theme per flavour), `bin/nekoshell-doctor` (`tool: atuin`), `README.md`, `docs/INSTALL.md`, `CHANGELOG.md`, `THIRD_PARTY.md`, `tests/zsh_stack.bats`, `tests/iterm_profiles.bats`, `tests/install.bats` (Brewfile test)
- Create: `stow/config/.config/nekoshell/zsh/fzf.zsh`, `stow/config/.config/atuin/config.toml`, `data/zsh-syntax-highlighting/catppuccin_<flavour>-zsh-syntax-highlighting.zsh` (four files vendored from catppuccin/zsh-syntax-highlighting, MIT), `tests/polish.bats`

**Interfaces:**
- Consumes: Task 11's `theme_render` and `~/.config/nekoshell/theme.zsh`; Task 10's prompt; `bin/nekoshell-music` untouched.
- Produces: nothing downstream.

The list:

1. **fzf previews.** `fzf.zsh` (sourced from `.zshrc` after `fzf --zsh`): `FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}' --preview-window=right:60%"`, `FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons --color=always {}'"`, `FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window=down:3:wrap"`, and `FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'` when `fd` is present. fzf-tab: `zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --icons --color=always -1 $realpath'` and `zstyle ':fzf-tab:*' use-fzf-default-opts yes`.
2. **Themed syntax highlighting.** Vendor the four Catppuccin zsh-syntax-highlighting theme files (pinned commit in THIRD_PARTY.md). `theme_render` appends `source "$NEKOSHELL_ROOT/data/zsh-syntax-highlighting/catppuccin_<flavor>-zsh-syntax-highlighting.zsh"` to `theme.zsh`; `.zshrc` sources `theme.zsh` BEFORE antidote loads the plugins (the theme file sets `ZSH_HIGHLIGHT_STYLES`, which the plugin reads at load). Autosuggestions: `ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#<overlay0 of the flavour>"` also in `theme.zsh`.
3. **atuin.** Add `brew "atuin"` to the Brewfile; `stow/config/.config/atuin/config.toml` with `auto_sync = false`, `update_check = false`, `style = "compact"`, `inline_height = 20`, `search_mode = "fuzzy"`, `filter_mode_shell_up_key_binding = "session"`; `.zshrc`: `(( $+commands[atuin] )) && eval "$(atuin init zsh --disable-up-arrow)"` after fzf (Ctrl-R goes to atuin; up arrow stays plain). Doctor: add `atuin` to the tool list. Brewfile test: expect `brew "atuin"`.
4. **iTerm2 profile extras** in `iterm2/build-profiles.py` main profile: `"Use Cursor Guide": True`, `"Dim Inactive Split Panes": True`, `"Dimming Amount": 0.3`, `"Window Type": 0` unchanged, `"Show Status Bar": True` with a `"Status Bar Layout"` dict. Research step: fetch iTerm2's `sources/iTermStatusBarLayout.h`, `sources/iTermStatusBarLayout.m` and one component (`sources/iTermStatusBarClockComponent.m`) via `gh api` + raw URLs (as earlier tasks did) to learn the exact dictionary keys (`components`, each with `class` and `configuration` with `knobs`, plus `advanced configuration`). Components, left to right: `iTermStatusBarWorkingDirectoryComponent`, `iTermStatusBarGitComponent`, spring (`iTermStatusBarSpringComponent`), `iTermStatusBarCPUUtilizationComponent`, `iTermStatusBarMemoryUtilizationComponent`, `iTermStatusBarBatteryComponent`, `iTermStatusBarClockComponent`. Colours from the flavour: status bar background `mantle`, text `text`, separators `surface1` (the advanced configuration keys for these are in the header). If, after reading the source, you are not confident the dictionary is right, still emit it (iTerm2 ignores unknown layouts rather than failing) and say so in the report; the owner verifies visually. Working directory and git components need iTerm2 shell integration: add `[[ -r "$HOME/.iterm2_shell_integration.zsh" ]] && source "$HOME/.iterm2_shell_integration.zsh"` to `.zshrc`, have `install.sh` download it with `curl -fsSL https://iterm2.com/shell_integration/zsh -o "$HOME/.iterm2_shell_integration.zsh"` (via `run`, skipped in dry-run, `--skip-brew` does not skip it), and add it to the backup list and to the uninstall "left in place" list.
5. **Tests** (`tests/polish.bats`): fzf.zsh parses (`zsh -n`); sourcing `.zshrc` in the temp HOME with `HOMEBREW_PREFIX=/nonexistent` still works with the new lines; `atuin/config.toml` is valid TOML with `auto_sync = false`; the profile JSON has `Show Status Bar` true and a `Status Bar Layout` with seven components in that order; the four highlighting theme files exist and each defines `ZSH_HIGHLIGHT_STYLES`.

- [ ] **Step 1: Write tests/polish.bats and the test updates; run to see them fail**
- [ ] **Step 2: Implement items 1 to 4**
- [ ] **Step 3: Run `bats tests && shellcheck -x install.sh uninstall.sh lib/*.sh bin/* && zsh -n stow/zsh/.zshrc stow/config/.config/nekoshell/zsh/*.zsh`**
- [ ] **Step 4: Docs (README "What you get" and "Customise", INSTALL troubleshooting for the status bar needing a new window, CHANGELOG, THIRD_PARTY) and commit** with subject `feat: fzf previews, themed highlighting, atuin, iTerm2 status bar`.

---

