# yazi, gh, mise and pure Plugins Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Four plugins picked from the terminals-are-sexy list: `yazi` (file manager, themed), `gh` (GitHub CLI completions and pager), `mise` (runtime versions) and `pure` (a third prompt).

**Architecture:** Each is an ordinary plugin under `plugins/<name>/` following the existing shapes: p10k for a prompt that takes over from Starship, tmux for a rendered theme file plus a copied-once config, fzf for a `plugin.zsh` that only wires a tool that is on PATH. Nothing touches a file the user owns except by copying it once.

**Tech Stack:** bash 3.2, zsh, Homebrew formulas `yazi`, `gh`, `mise`, `pure`; bats with new fakes `yazi`, `gh`, `mise`.

**Spec:** `docs/superpowers/specs/2026-09-13-art-providers-and-plugins-design.md`, section 2.

## Global Constraints

- The same as the art providers plan: bash 3.2, shellcheck and shfmt clean, nine toml keys, five README sections, a docs page, a bats file per plugin, conventional commits with the trailer.
- Branch: `feat/list-plugins` from `main` (after the art providers PR merges, or rebased onto it).
- A `plugin.zsh` costs a shell nothing measurable when its tool is missing: guard everything with `(( $+commands[tool] ))`.

---

### Task 1: yazi

**Files:**

- Create: `plugins/yazi/plugin.toml`, `plugins/yazi/plugin.zsh`, `plugins/yazi/theme.sh`, `plugins/yazi/uninstall.sh`, `plugins/yazi/doctor.sh`, `plugins/yazi/README.md`, `plugins/yazi/files/theme.toml.tmpl`, `plugins/yazi/files/copy/.config/yazi/yazi.toml`, `docs/plugins/yazi.md`, `tests/fakes/yazi`
- Modify: `THIRD_PARTY.md`
- Test: `tests/plugins/yazi.bats`

**Interfaces:**

- Produces: `~/.config/yazi/theme.toml` rendered (header names nekoshell), `~/.config/yazi/yazi.toml` copied once (`copy_guard`), the `y` shell function.

- [ ] **Step 1: The template**

Build `files/theme.toml.tmpl` from yazi-rs/flavors `catppuccin-mocha.yazi/flavor.toml` (fetch with `gh api repos/yazi-rs/flavors/contents/catppuccin-mocha.yazi/flavor.toml -H 'Accept: application/vnd.github.raw'`; record the commit from `gh api repos/yazi-rs/flavors/commits/HEAD --jq .sha`). Replace every hex with its palette role by a throwaway python script in the scratchpad:

```python
import json, re, sys
p = json.load(open("core/theme/palettes.json"))["mocha"]
back = {("#" + v).lower(): k for k, v in p.items()}
src = open(sys.argv[1]).read()
missing = set()
def repl(m):
    h = m.group(0).lower()
    if h in back: return "@@HEX:%s@@" % back[h]
    missing.add(h); return h
out = re.sub(r'#[0-9a-fA-F]{6}', repl, src)
header = "# nekoshell: rendered for the @@TITLE@@ flavour by the yazi plugin.\n# Changed by `nekoshell theme <flavour>`, not by hand: edit\n# plugins/yazi/files/theme.toml.tmpl instead.\n\n"
open("plugins/yazi/files/theme.toml.tmpl", "w").write(header + out)
print("unmapped:", sorted(missing))
```

Expected: `unmapped: []`. If a hex is not a palette colour, map it by hand to the nearest role and say so in a comment.

- [ ] **Step 2: Failing tests**

`tests/plugins/yazi.bats` (setup as in p10k.bats, `P="$REPO_ROOT/plugins/yazi"`):

```bash
@test "plugin.toml is complete and the README has its five sections" { ... }

@test "add installs yazi, copies yazi.toml once and renders the theme" {
  run "$NK" plugin add yazi
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install yazi"
  [ -f "$HOME/.config/yazi/yazi.toml" ]
  [ ! -L "$HOME/.config/yazi/yazi.toml" ]
  head -1 "$HOME/.config/yazi/theme.toml" | grep -q nekoshell
  grep -q 'cwd = { fg = "#94e2d5" }' "$HOME/.config/yazi/theme.toml"
}

@test "an existing yazi.toml is left alone" {
  mkdir -p "$HOME/.config/yazi"; echo mine > "$HOME/.config/yazi/yazi.toml"
  run "$NK" plugin add yazi
  assert_contains "$output" ".config/yazi/yazi.toml exists; left your config alone"
  [ "$(cat "$HOME/.config/yazi/yazi.toml")" = mine ]
}

@test "a theme switch re-renders theme.toml and a theme of your own is backed up first" {
  mkdir -p "$HOME/.config/yazi"; echo mine > "$HOME/.config/yazi/theme.toml"
  "$NK" plugin add yazi >/dev/null
  [ -n "$(find "$HOME/.local/share/nekoshell/backup" -name theme.toml)" ]
  run "$NK" theme latte
  grep -q 'cwd = { fg = "#179299" }' "$HOME/.config/yazi/theme.toml"
}

@test "y changes directory to where yazi quit" {
  "$NK" plugin add yazi >/dev/null
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  mkdir -p "$HOME/there"
  run zsh -o NO_GLOBAL_RCS -ic 'cd "$HOME"; FAKE_YAZI_CWD="$HOME/there" y; pwd; exit 0'
  assert_contains "$output" "$HOME/there"
}

@test "doctor reports yazi and the rendered theme" {
  "$NK" plugin add yazi >/dev/null
  run "$NK" doctor --plugin yazi
  assert_matches "$output" 'ok +tool: yazi'
  assert_matches "$output" 'ok +yazi theme +mocha'
  rm "$HOME/.config/yazi/theme.toml"
  run "$NK" doctor --plugin yazi
  assert_matches "$output" 'fail +yazi theme'
}

@test "remove drops the rendered theme and keeps yazi.toml" {
  "$NK" plugin add yazi >/dev/null
  run "$NK" plugin remove yazi
  [ ! -e "$HOME/.config/yazi/theme.toml" ]
  [ -f "$HOME/.config/yazi/yazi.toml" ]
}
```

Fake `tests/fakes/yazi`: writes `$FAKE_YAZI_CWD` into the path given by `--cwd-file=PATH` when set; prints `yazi $*`; `--version` prints `Yazi 26.9.1`.

- [ ] **Step 3: Run to verify they fail**

- [ ] **Step 4: Implementation**

`plugin.toml`: name `yazi`, summary "yazi, a terminal file manager, in the flavour, with `y` that lands you where you quit", `requires = ["yazi"]`, tags `["shell"]`, `copy_guard = [".config/yazi/yazi.toml"]`.

`files/copy/.config/yazi/yazi.toml`:

```toml
# yazi settings. Yours from the moment nekoshell copied it: it is never
# overwritten. The colours are in theme.toml beside it, which nekoshell
# renders on every theme switch. Reference:
# https://yazi-rs.github.io/docs/configuration/yazi
[mgr]
show_hidden = false
sort_by = "natural"
sort_dir_first = true
```

`plugin.zsh`:

```zsh
# yazi's documented shell wrapper: y opens yazi and, on quit, changes to the
# directory it was in. Guarded, so a shell without yazi pays one lookup.
if (( $+commands[yazi] )); then
  y() {
    local tmp cwd
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
      builtin cd -- "$cwd" || return
    fi
    rm -f -- "$tmp"
  }
fi
true
```

`theme.sh`: `mkdir -p "$HOME/.config/yazi"; theme_clear_stale_link ...; theme_backup_foreign "$HOME/.config/yazi/theme.toml"; theme_render_template "$PLUGIN_DIR/files/theme.toml.tmpl" "$HOME/.config/yazi/theme.toml" "$FLAVOR"`.

`uninstall.sh`: remove `~/.config/yazi/theme.toml` through `run rm -f` when `theme_is_rendered` says it is ours.

`doctor.sh`: `tool: yazi` (path or `missing (nekoshell plugin add yazi)`), `yazi theme` ok with the flavour when the rendered file's header carries `$(theme_title "$FLAVOR")`, else fail `not rendered for $FLAVOR (run: nekoshell theme $FLAVOR)`.

README, docs page, THIRD_PARTY row (`plugins/yazi/files/theme.toml.tmpl` derived from yazi-rs/flavors catppuccin-mocha at the recorded commit, MIT).

- [ ] **Step 5: Run, lint, commit**

```bash
git add -A plugins/yazi docs/plugins/yazi.md tests/plugins/yazi.bats tests/fakes/yazi THIRD_PARTY.md
git commit -m "feat(yazi): yazi in the flavour, with y that lands where you quit"
```

---

### Task 2: gh

**Files:**

- Create: `plugins/gh/{plugin.toml,plugin.zsh,doctor.sh,README.md}`, `docs/plugins/gh.md`, `tests/fakes/gh`
- Test: `tests/plugins/gh.bats`

**Interfaces:**

- Produces: `~/.cache/nekoshell/gh-completion.zsh` (regenerated when gh is newer), `GH_PAGER=delta` when delta is on PATH.

- [ ] **Step 1: Failing tests**

Fake `gh`: `completion -s zsh` prints `#compdef gh` and `_gh() { :; }` and `compdef _gh gh 2>/dev/null`; `auth status` exits 0 printing `Logged in to github.com` unless `FAKE_GH_LOGGED_OUT=1` (exit 1, `You are not logged in`); `--version` prints `gh version 2.100.0`; anything else echoes `gh $*`.

Tests: contract; "add installs gh and writes nothing into your home except the completion cache" (`brew install gh`, `~/.config/gh` absent); "the shell caches the completion and sets GH_PAGER when delta is there" (zsh -ic with `FAKE` delta on PATH: `[ -s cache ]`, `echo $GH_PAGER` = delta, `(( $+functions[_gh] ))`); "without delta GH_PAGER stays unset"; "doctor reports the binary and the login" (ok/warn rows: `gh auth` warn `not logged in (run: gh auth login)` with `FAKE_GH_LOGGED_OUT=1`).

- [ ] **Step 2: Implementation**

`plugin.zsh`:

```zsh
# gh: completions cached to a file (gh takes a few tens of milliseconds to
# print them), regenerated when the binary is newer than the cache; delta as
# the pager for diffs when the modern-cli plugin put it on PATH.
if (( $+commands[gh] )); then
  _nk_gh_comp="$HOME/.cache/nekoshell/gh-completion.zsh"
  if [[ ! -s "$_nk_gh_comp" || "$commands[gh]" -nt "$_nk_gh_comp" ]]; then
    mkdir -p "$HOME/.cache/nekoshell"
    gh completion -s zsh >| "$_nk_gh_comp" 2>/dev/null
  fi
  [[ -s "$_nk_gh_comp" ]] && source "$_nk_gh_comp"
  unset _nk_gh_comp
  (( $+commands[delta] )) && export GH_PAGER="delta"
fi
true
```

`doctor.sh`: `tool: gh`; `gh auth` ok `logged in` / warn `not logged in (run: gh auth login)` / skipped when gh is missing.

README says the plugin touches nothing under `~/.config/gh`. Docs page.

- [ ] **Step 3: Run, lint, commit**

```bash
git commit -m "feat(gh): github cli completions and delta as its pager"
```

---

### Task 3: mise

**Files:**

- Create: `plugins/mise/{plugin.toml,plugin.zsh,doctor.sh,README.md}`, `plugins/mise/files/copy/.config/mise/config.toml`, `docs/plugins/mise.md`, `tests/fakes/mise`
- Test: `tests/plugins/mise.bats`

- [ ] **Step 1: Failing tests**

Fake `mise`: `activate zsh` prints `export MISE_FAKE_ACTIVATED=1`; `completion zsh` prints `#compdef mise` and `_mise() { :; }`; `--version` prints `2026.9.6`; `ls` prints nothing.

Tests: contract; "add installs mise and copies config.toml once" (`copy_guard`); "the shell activates mise and caches its completion" (`MISE_FAKE_ACTIVATED=1`, cache file present); "doctor reports the binary and the config".

- [ ] **Step 2: Implementation**

`plugin.toml`: `requires = ["mise"]`, tags `["shell"]`, `copy_guard = [".config/mise/config.toml"]`.

`files/copy/.config/mise/config.toml`:

```toml
# mise: global tool versions. Yours from the moment nekoshell copied it.
# Add tools here or with `mise use -g node@lts`. Reference:
# https://mise.jdx.dev/configuration.html
[tools]
```

`plugin.zsh`: guarded `eval "$(mise activate zsh)"` and the same completion cache pattern as gh (`~/.cache/nekoshell/mise-completion.zsh`, `mise completion zsh`).

`doctor.sh`: `tool: mise`; `mise config` ok with the path when `~/.config/mise/config.toml` exists, warn otherwise.

- [ ] **Step 3: Run, lint, commit**

```bash
git commit -m "feat(mise): runtime versions with mise, activated in every shell"
```

---

### Task 4: pure

**Files:**

- Create: `plugins/pure/{plugin.toml,plugin.zsh,theme.sh,doctor.sh,README.md}`, `plugins/pure/files/pure-colors.zsh.tmpl`, `docs/plugins/pure.md`
- Modify: `plugins/p10k/plugin.toml` (`conflicts = ["pure"]`), `docs/plugins/p10k.md`
- Test: `tests/plugins/pure.bats`, `tests/plugins/p10k.bats` (a conflict test)

- [ ] **Step 1: Check the formula**

`brew install pure` on this Mac, then `ls "$(brew --prefix)/share/zsh/site-functions/" | grep -E 'prompt_pure_setup|async'`. Expected: both files. If `async` is missing, pure cannot run and the plugin must source `async.zsh` from the formula's `share/pure` instead; adjust `plugin.zsh` to whatever the formula lays down.

- [ ] **Step 2: Failing tests**

`tests/plugins/pure.bats` setup creates a fake Homebrew prefix: `mkdir -p "$HOME/fakebrew/share/zsh/site-functions"`, a `prompt_pure_setup` file containing `prompt_pure_setup() { PROMPT='pure> ' }` and an `async` file containing `async_init() { :; }`, and exports `HOMEBREW_PREFIX="$HOME/fakebrew"`.

Tests: contract (plus `conflicts = ["p10k"]`); "add installs pure and renders the colours" (`brew install pure`, `~/.config/nekoshell/pure-colors.zsh` has `zstyle ':prompt:pure:prompt:success' color '#cba6f7'` and `Mocha`); "the zshrc lets pure take the prompt and skips starship" (like p10k's: `prompt=pure`, no `STARSHIP-ON`, `PROMPT` is `pure>`); "a theme switch re-renders the colours" (latte: `#8839ef`); "pure and p10k refuse each other" (`plugin add p10k` then `plugin add pure` fails with `pure conflicts with p10k`); "doctor reports the prompt function and the colours"; "remove hands the prompt back to starship".

- [ ] **Step 3: Implementation**

`plugin.toml`: `requires = ["pure"]`, tags `["prompt", "shell"]`, `conflicts = ["p10k"]`.

`files/pure-colors.zsh.tmpl`:

```zsh
# Generated by nekoshell for the @@TITLE@@ flavour. Sourced by the pure plugin
# before the prompt is set up. Changed by `nekoshell theme <flavour>`, not by
# hand: the next switch overwrites it.
zstyle ':prompt:pure:path' color '@@HEX:blue@@'
zstyle ':prompt:pure:git:branch' color '@@HEX:overlay1@@'
zstyle ':prompt:pure:git:branch:cached' color '@@HEX:red@@'
zstyle ':prompt:pure:git:dirty' color '@@HEX:overlay1@@'
zstyle ':prompt:pure:git:arrow' color '@@HEX:teal@@'
zstyle ':prompt:pure:git:stash' color '@@HEX:teal@@'
zstyle ':prompt:pure:git:action' color '@@HEX:yellow@@'
zstyle ':prompt:pure:prompt:success' color '@@HEX:mauve@@'
zstyle ':prompt:pure:prompt:error' color '@@HEX:red@@'
zstyle ':prompt:pure:prompt:continuation' color '@@HEX:overlay0@@'
zstyle ':prompt:pure:execution_time' color '@@HEX:yellow@@'
zstyle ':prompt:pure:virtualenv' color '@@HEX:overlay1@@'
zstyle ':prompt:pure:host' color '@@HEX:overlay1@@'
zstyle ':prompt:pure:user' color '@@HEX:overlay1@@'
zstyle ':prompt:pure:user:root' color '@@HEX:red@@'
zstyle ':prompt:pure:git:stash' show yes
```

`plugin.zsh`:

```zsh
# pure in place of Starship. NEKOSHELL_PROMPT tells the core zshrc not to
# start Starship; the prompt functions are Homebrew's, under whichever prefix
# this Mac uses; the colours come from the file the theme hook renders.
export NEKOSHELL_PROMPT=pure
for _nk_p in "${HOMEBREW_PREFIX:-/opt/homebrew}" /opt/homebrew /usr/local; do
  if [[ -r "$_nk_p/share/zsh/site-functions/prompt_pure_setup" ]]; then
    fpath=("$_nk_p/share/zsh/site-functions" $fpath)
    break
  fi
done
unset _nk_p
[[ -r "$NEKOSHELL_CONFIG/pure-colors.zsh" ]] && source "$NEKOSHELL_CONFIG/pure-colors.zsh"
autoload -Uz promptinit && promptinit && prompt pure
true
```

`theme.sh` renders the template to `$NEKOSHELL_CONFIG/pure-colors.zsh`. `doctor.sh`: `pure prompt` (the `prompt_pure_setup` path or fail), `pure colours` (flavour title in the rendered file). p10k's toml gets `conflicts = ["pure"]`, and its docs page a line about it.

- [ ] **Step 4: Run, lint, commit**

Run: `bats tests/plugins/pure.bats tests/plugins/p10k.bats tests/core/repo.bats && scripts/lint.sh`

```bash
git commit -m "feat(pure): the pure prompt as a third prompt option"
```

---

### Task 5: Docs, verification on this Mac, PR

- [ ] **Step 1: Docs**

`docs/plugins/README.md`: four table rows; `README.md` plugin list; `CHANGELOG.md`: "yazi, gh, mise and pure plugins"; the shipped-plugin count.

- [ ] **Step 2: On this Mac**

```bash
./bin/nekoshell plugin add yazi gh mise
./bin/nekoshell doctor --plugin yazi; ./bin/nekoshell doctor --plugin gh; ./bin/nekoshell doctor --plugin mise
env -u CLAUDECODE zsh -ic 'type y; echo $GH_PAGER; mise --version; exit 0'
```

pure conflicts with p10k, which is enabled here: verify it in a throwaway HOME instead (`HOME=$(mktemp -d) ./bin/nekoshell install --profile minimal --with pure --terminal kitty --yes` then `HOME=... zsh -ic 'echo $NEKOSHELL_PROMPT; exit 0'`), and leave the user's prompt as it is.

- [ ] **Step 3: PR**

`gh pr create` on `feat/list-plugins` with the What/Checks body shape of the art providers PR and the attribution line.
