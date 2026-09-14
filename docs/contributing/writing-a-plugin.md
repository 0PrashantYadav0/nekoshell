# Writing a plugin

A walkthrough from an empty directory to a plugin that passes `make check`. The contract it follows is in [docs/plugins/ARCHITECTURE.md](../plugins/ARCHITECTURE.md).

## 1. Copy the fixture

`tests/fixtures/plugins/demo` is a working plugin with one of everything, and the test suite keeps it working.

```bash
cp -R tests/fixtures/plugins/demo plugins/<name>
```

It gives you this:

```text
plugins/<name>/
  plugin.toml
  install.sh
  uninstall.sh
  doctor.sh
  plugin.zsh
  late.zsh
  antidote.txt
  bin/nekoshell-demo
  cmd/demo.sh
  files/link/.config/demo/conf
  files/copy/.config/demo/mine.conf
```

Delete every file your plugin does not need. A missing hook is not an error; an empty one is noise.

## 2. Fill in plugin.toml

All nine keys must be there, even when empty. `scripts/lint.sh` and `tests/core/repo.bats` both fail a plugin that is missing one. The demo's file:

```toml
name = "demo"
summary = "A fixture plugin"
requires = ["eza"]
casks = []
taps = []
requires_plugins = []
terminals = ["any"]
conflicts = []
tags = ["shell"]
```

| Key | What to put in it |
| --- | --- |
| `name` | the directory name, exactly |
| `summary` | one line, no full stop; it is the heading `plugin add` prints |
| `requires` | Homebrew formulas |
| `casks` | Homebrew casks |
| `taps` | taps, tapped before either |
| `requires_plugins` | plugins that must be enabled first; they are added for you |
| `terminals` | `["any"]`, or the adapter ids this only works in |
| `conflicts` | plugins that must not be on at the same time |
| `tags` | free words; `media` is the one `nekoshell music` reads |

`copy_guard` is optional and goes after the nine. Add it when your `files/copy` tree is a set that must not be half-applied:

```toml
copy_guard = [".tmux.conf", ".config/tmux/tmux.conf"]
```

One guard path present under `$HOME` skips the whole copy, with a warning naming your `files/copy` directory.

## 3. Choose link or copy

The rule is who owns the file afterwards.

- `files/link/<rel>` becomes a symlink `$HOME/<rel>` into the checkout. Use it for a file nekoshell owns and `git pull` should change: the four btop theme files, the bat themes, the atuin config.
- `files/copy/<rel>` is copied when it is not there and never written again. Use it for a file the user will edit: `~/.p10k.zsh`, `~/.config/mise/config.toml`, the tmux config.
- A `.tmpl` goes directly under `files/`, not in either tree, and your `theme.sh` renders it.

## 4. Write the hooks you need

Each hook runs in a subshell with `set -euo pipefail`, the libraries sourced, and `PLUGIN_NAME`, `PLUGIN_DIR` and `FLAVOR` exported. End each one with `true` so a last command that is legitimately false does not fail the hook.

`install.sh`, on add. Use `run` for anything that changes the machine, so `--dry-run` prints instead of doing:

```bash
#!/usr/bin/env bash
echo "demo install FLAVOR=$FLAVOR PLUGIN_DIR=$PLUGIN_DIR" >>"$NEKOSHELL_CACHE/hooks.log"
```

`theme.sh`, on add and on every `nekoshell theme`. Render, never write a colour:

```bash
theme_render_template "$PLUGIN_DIR/files/theme.toml.tmpl" "$HOME/.config/yazi/theme.toml" "$FLAVOR"
```

`doctor.sh`, on `nekoshell doctor`. One `report` call per row:

```bash
#!/usr/bin/env bash
report ok "demo" "fine"
```

`uninstall.sh`, on remove, takes back what `install.sh` did and nothing else.

## 5. Write the two READMEs

`plugins/<name>/README.md` needs exactly these five headings, in this order. `tests/core/repo.bats` checks them and `nekoshell plugin info <name>` prints the file:

```text
## What it does
## Installs
## Files
## After install
## Remove
```

The installer prints the "After install" section at the end of a run, so put the steps only a person can take there and nothing else.

`docs/plugins/<name>.md` is the user page, with these five headings:

```text
## What you get
## Using it
## Files
## Theme
## Turning it off
```

Add a row to the table at the end of [docs/plugins/README.md](../plugins/README.md): the link, what it is, its tags, what it needs.

## 6. Add a fake for every tool the hooks call

Tests never run a real tool. A fake is a short executable in `tests/fakes/` that answers what the code asks and reads `FAKE_*` variables for anything a test needs to vary. `tests/fakes/fzf` is the whole idea in fifteen lines:

```bash
#!/usr/bin/env bash
# Fake fzf: `--zsh` prints the key bindings, which a zsh can source without
# side effects here. FAKE_FZF_PICK=N prints the Nth line of stdin, the way a
# person choosing that row would; otherwise stdin is drained and the
# arguments go to stderr (stdout is the pick, and there is none), so a caller
# that captures the pick sees nothing and a test sees the flags.
if [[ "${1:-}" == "--zsh" ]]; then
  echo ': fzf key bindings'
  exit 0
fi
if [[ -n "${FAKE_FZF_PICK:-}" ]]; then
  sed -n "${FAKE_FZF_PICK}p"
  exit 0
fi
cat >/dev/null
echo "fzf $*" >&2
```

A fake that only has to exist is one line: `tests/fakes/btop` is `echo "btop $*"`. Make it executable; `scripts/lint.sh` checks that every file under `tests/fakes` is.

## 7. Write the bats file

`tests/plugins/<name>.bats`, modelled on `tests/plugins/fzf.bats`. Its setup gives the test a throwaway `HOME`, puts the fakes in front of `PATH`, points the terminal lookup at the fixtures, and writes a `nekoshell.toml` so the libraries have a machine to read:

```bash
#!/usr/bin/env bats
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/fzf"
}
teardown() { teardown_tmp_home; }
```

Start with the shape test and one that adds the plugin. These two are the floor:

```bash
@test "plugin.toml is complete and the README has its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
}

@test "add installs fzf" {
  run "$NK" plugin add fzf
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install fzf"
}
```

Then one test per thing your plugin actually does: what remove takes back out, what the doctor reports, what the zsh files define. Use `[ ]` and the helpers rather than `[[ ]]`; [testing.md](testing.md) says why.

## 8. Check it

```bash
scripts/lint.sh plugins/<name>/*.sh docs/plugins/<name>.md
bats tests/plugins/<name>.bats
make check
```

## 9. Changelog

Add a line under `## 0.2.0 (unreleased)`, in the section that fits:

```markdown
- `<name>`: one sentence saying what a user gets.
```
