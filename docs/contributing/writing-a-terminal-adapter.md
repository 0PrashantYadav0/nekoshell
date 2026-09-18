# Writing a terminal adapter

An adapter teaches nekoshell how one terminal is detected, themed, panelled and undone. Five ship: `iterm2`, `kitty`, `ghostty`, `warp`, `terminal-app`. kitty is the one to read first; everything below quotes it.

## 1. Read the contract

`terminals/adapter.sh` defines every function with a default and is sourced before your file, so your adapter overrides what it supports. Read it before anything else.

`terminal_load ID` always takes the contract from the checkout, whatever `NEKOSHELL_TERMINALS_DIR` points at, so a test fixture can replace an adapter but never the defaults.

## 2. Create terminals/&lt;id&gt;/adapter.sh

All ten functions must be defined in your own file, even the ones you leave at the default. `scripts/lint.sh` greps for each `name()` at the start of a line and `tests/core/repo.bats` does the same, so an adapter missing one fails the build.

| Function | Arguments | What it must do |
| --- | --- | --- |
| `terminal_name` | none | print the id, the directory's own name |
| `terminal_detect` | none | status 0 when this shell is running in the terminal |
| `terminal_installed` | none | status 0 when the app is on this Mac |
| `terminal_capabilities` | none | print words from `truecolor images background panel hotkey` |
| `terminal_font_name` | none | the Nerd Font, spelled the way this terminal's config wants it |
| `terminal_apply` | `FLAVOR` | write the font and the colours into the terminal's config |
| `terminal_background` | `PATH\|none [OPACITY]` | set or clear a background image |
| `terminal_panel` | `CMD...` | run `CMD` in the terminal's panel or overlay |
| `terminal_remove` | none | take back exactly what `terminal_apply` wrote |
| `terminal_doctor` | none | call `report status check detail` for its own rows |

The four short ones, from kitty:

```bash
terminal_name() { echo "kitty"; }
terminal_detect() { [[ -n "${KITTY_WINDOW_ID:-}" || "${TERM:-}" == "xterm-kitty" ]]; }
terminal_installed() {
  [[ -e "/Applications/kitty.app" || -e "$HOME/Applications/kitty.app" ]] || command -v kitty >/dev/null 2>&1
}
terminal_capabilities() { echo "truecolor images background panel hotkey"; }
```

`terminal_panel` may delegate the half it does not replace. kitty uses tmux's popup inside tmux and the quick-access terminal only when the shell is really in kitty:

```bash
terminal_panel() {
  if [[ -n "${TMUX:-}" ]] || ! terminal_detect; then
    terminal_panel_default "$@"
    return $?
  fi
  ...
}
```

Three rules the shipped adapters keep:

- Back the user's own config file up once, before the first edit, and put back only what you added on `terminal_remove`. kitty's `_kitty_backup_conf` and `kitty_remove_include` are the pattern.
- Honour `NEKOSHELL_DRY_RUN=1`: log what would happen and write nothing.
- Write nothing a render can write. Colours come from the template.

## 3. Teach detection to the two places that ask

`terminal_detect` is only consulted once an adapter is loaded. Two other places have to recognise the terminal from the environment alone, and both need editing:

- `terminal_detect_env` in `core/lib/terminal.sh`. It tests `KITTY_WINDOW_ID` and `TERM`, then `GHOSTTY_RESOURCES_DIR`, then `WEZTERM_EXECUTABLE`, then a `case` on `TERM_PROGRAM` for `iTerm.app`, `Apple_Terminal` and `WarpTerminal`.
- The same tests inline in `core/zsh/.zshrc`, in the block that sets `_nk_term`, which picks the `terminals/<id>/zsh.zsh` to source. They are written out again there rather than shared, because the zshrc must not start a process to find out which terminal it is in.

## 4. Add a template for the colours

Put a `.tmpl` next to the adapter and render it with `theme_render_template`, so `core/theme/palettes.json` stays the only place a colour is written. kitty has `nekoshell.conf.tmpl` and `nekoshell-panel.conf.tmpl`; ghostty has `nekoshell.tmpl`; warp has `theme.yaml.tmpl`. The placeholders are `@@FLAVOR@@`, `@@TITLE@@`, `@@hex:ROLE@@`, `@@HEX:ROLE@@`, `@@sgr:ROLE@@` and `@@rgb:ROLE@@`. ANSI 0 to 15 come from the `ansiblack` ... `ansibrwhite` roles, never from a design role picked by hand: those roles are per flavour, which is what keeps black readable on latte.

Start the rendered file with a header naming nekoshell and the flavour. `theme_is_rendered` reads the first ten lines to tell a file nekoshell wrote from one the user wrote, and kitty's own doctor reads the flavour back out of that header.

## 5. Add zsh.zsh if the terminal needs shell integration

`terminals/<id>/zsh.zsh` is sourced by the core zshrc when the shell is running in that terminal, early, before the plugins load. Only ghostty ships one: Ghostty's quick terminal starts a plain shell with no way to hand it a command, so the hook turns the first interactive shell inside it into the music panel. Write it in zsh, with no bashisms.

## 6. Write the README

`terminals/<id>/README.md`, with exactly these five headings:

```text
## What it configures
## Panel
## Images
## Uninstall
## Known limits
```

## 7. Write the bats file

`tests/terminals/<id>.bats`, modelled on `tests/terminals/kitty.bats`. Its setup points at the real adapters directory, not the fixtures, because the adapter is what is under test:

```bash
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_ROOT="$REPO_ROOT"
  unset NEKOSHELL_TERMINALS_DIR
  ...
}
```

Sourcing the libraries brings in `log.sh`'s `run`, which shadows bats' own `run` for the rest of the process, so a test that loads an adapter captures with `$( )` instead. kitty does that through one helper:

```bash
load_adapter() {
  local l
  for l in log paths backup config theme terminal; do
    # shellcheck source=/dev/null
    source "$REPO_ROOT/core/lib/$l.sh"
  done
  terminal_load kitty
}
```

The contract test every adapter should have:

```bash
@test "name, capabilities and font" {
  load_adapter
  [ "$(terminal_name)" = "kitty" ]
  [ "$(terminal_capabilities)" = "truecolor images background panel hotkey" ]
  [ "$(terminal_font_name)" = "JetBrainsMono Nerd Font" ]
}
```

Then one per behaviour: detection under each environment variable, what `terminal_apply` writes, what `terminal_remove` takes back out, the doctor rows. Never touch the developer's real app: kitty's installed test skips itself when `/Applications/kitty.app` exists.

## 8. Add the id to the CI matrix

`.github/workflows/ci.yml` runs the installer once per adapter. Add your id to the list:

```yaml
    strategy:
      fail-fast: false
      matrix:
        terminal: [iterm2, kitty, ghostty, warp, terminal-app]
```

That job runs `./bin/nekoshell install --check --profile full --terminal "${{ matrix.terminal }}"` against a throwaway `HOME` with `NEKOSHELL_SKIP_PREFLIGHT=1`, which is the end-to-end proof the adapter loads.

## 9. Check it

```bash
scripts/lint.sh terminals/<id>/adapter.sh terminals/<id>/README.md
bats tests/terminals/<id>.bats
make check
```
