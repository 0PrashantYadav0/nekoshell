#!/usr/bin/env bats
# The Ghostty terminal adapter: the rendered config file, the include line in
# Ghostty's main config, the adapter contract on top of them, and the rows it
# reports to the doctor.
load ../helpers

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_ROOT="$REPO_ROOT"
  # The real adapters directory, not the fixtures one: ghostty is the adapter
  # under test. Unset rather than pointed at terminals/, so core/lib/terminal.sh
  # derives it the way a real run does.
  unset NEKOSHELL_TERMINALS_DIR
  unset NEKOSHELL_PANEL NEKOSHELL_DRY_RUN NEKOSHELL_BACKUP_DIR TMUX TERM_PROGRAM GHOSTTY_RESOURCES_DIR
  export TERM=xterm-256color
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell" "$HOME/.config/ghostty"
  printf 'root = "%s"\nterminal = "ghostty"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  OWNED="$HOME/.config/ghostty/nekoshell"
  CONF="$HOME/.config/ghostty/config"
  INCLUDE="config-file = nekoshell"
}
teardown() { teardown_tmp_home; }

# Sourcing the libraries pulls in log.sh's run(), which shadows bats' own run()
# for the rest of the test process; these tests capture with $( ) instead, the
# way tests/core/terminal.bats does. backup is loaded too: the adapter backs
# up a main config of the user's through backup_path.
load_adapter() {
  local l
  for l in log paths backup config theme terminal; do
    # shellcheck source=/dev/null
    source "$REPO_ROOT/core/lib/$l.sh"
  done
  terminal_load ghostty
}

# The Ghostty CLI, from the real PATH or the app bundle, for the tests that
# run its validator. Empty when it is not on this Mac.
ghostty_bin() {
  local b
  b="$(PATH=/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin command -v ghostty 2>/dev/null || true)"
  [[ -n "$b" ]] || { [[ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]] && b=/Applications/Ghostty.app/Contents/MacOS/ghostty; }
  printf '%s' "$b"
}

# One value per line, joined, for the tests that read the owned file after
# load_adapter and so cannot use bats' run().
owned_values() {
  local k out=""
  for k in "$@"; do out="$out${out:+ | }$(awk -F' = ' -v k="$k" '$1 == k { print $2; exit }' "$OWNED")"; done
  printf '%s' "$out"
}

# --- the adapter contract ----------------------------------------------------

@test "name, capabilities and font" {
  load_adapter
  [ "$(terminal_name)" = "ghostty" ]
  [ "$(terminal_capabilities)" = "truecolor images background panel hotkey" ]
  [ "$(terminal_font_name)" = "JetBrainsMono Nerd Font" ]
}

@test "terminal_detect follows GHOSTTY_RESOURCES_DIR or TERM_PROGRAM=ghostty" {
  load_adapter
  status=0; ( GHOSTTY_RESOURCES_DIR=/x terminal_detect ) || status=$?
  [ "$status" -eq 0 ]
  status=0; ( TERM_PROGRAM=ghostty terminal_detect ) || status=$?
  [ "$status" -eq 0 ]
  status=0; ( TERM_PROGRAM=iTerm.app terminal_detect ) || status=$?
  [ "$status" -eq 1 ]
  status=0; ( TERM=xterm-ghostty terminal_detect ) || status=$?
  [ "$status" -eq 1 ]
}

@test "terminal_installed follows the app bundle in either Applications dir" {
  load_adapter
  if [ -e /Applications/Ghostty.app ]; then skip "Ghostty is installed in /Applications on this Mac"; fi
  status=0; terminal_installed || status=$?
  [ "$status" -eq 1 ]
  mkdir -p "$HOME/Applications/Ghostty.app"
  status=0; terminal_installed || status=$?
  [ "$status" -eq 0 ]
}

# --- terminal_apply ----------------------------------------------------------

@test "terminal_apply renders the owned file with the flavour, font, colours and panel keys" {
  load_adapter
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ -f "$OWNED" ]
  assert_contains "$(head -n 1 "$OWNED")" "nekoshell"
  assert_contains "$(head -n 1 "$OWNED")" "(mocha)"
  [ "$(owned_values font-family font-size background foreground cursor-color selection-background)" = "JetBrainsMono Nerd Font | 15 | #1e1e2e | #cdd6f4 | #f5e0dc | #585b70" ]
  assert_contains "$(cat "$OWNED")" "palette = 0=#45475a"
  assert_contains "$(cat "$OWNED")" "palette = 5=#f5c2e7"
  assert_contains "$(cat "$OWNED")" "palette = 15=#a6adc8"
  [ "$(owned_values window-padding-x window-padding-y macos-option-as-alt quick-terminal-position quick-terminal-autohide quick-terminal-screen)" = "12 | 12 | true | right | true | main" ]
  assert_contains "$(cat "$OWNED")" "keybind = global:alt+m=toggle_quick_terminal"
  assert_not_contains "$(cat "$OWNED")" "@@"
  assert_not_contains "$(cat "$OWNED")" "background-image"
}

@test "terminal_apply creates the main config with the tagged include when there is none" {
  load_adapter
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(cat "$CONF")" = "# nekoshell
$INCLUDE" ]
  assert_contains "$output" "added '$INCLUDE'"
}

@test "terminal_apply appends the include to an existing config once and backs it up first" {
  load_adapter
  printf 'font-size = 18\n' > "$CONF"
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(cat "$CONF")" = "font-size = 18
# nekoshell
$INCLUDE" ]
  assert_contains "$output" "backing up your .config/ghostty/config"
  # The apply ran in a subshell, so the set it began is found by its path,
  # not through NEKOSHELL_BACKUP_DIR.
  set -- "$NEKOSHELL_BACKUP_ROOT"/*/
  [ $# -eq 1 ]
  [ "$(cat "$1/.config/ghostty/config")" = "font-size = 18" ]
  [ "$(cat "$1/manifest.txt")" = ".config/ghostty/config" ]
  # A second apply adds nothing and backs nothing up again.
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(grep -c "$INCLUDE" "$CONF")" -eq 1 ]
  [ "$(grep -c '# nekoshell' "$CONF")" -eq 1 ]
  assert_not_contains "$output" "backing up"
}

@test "terminal_apply adds a newline before the include when the config has none at the end" {
  load_adapter
  printf 'font-size = 18' > "$CONF"
  terminal_apply mocha >/dev/null 2>&1
  [ "$(cat "$CONF")" = "font-size = 18
# nekoshell
$INCLUDE" ]
}

@test "terminal_apply twice yields the same files" {
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  cp "$OWNED" "$HOME/owned.1"; cp "$CONF" "$HOME/conf.1"
  terminal_apply mocha >/dev/null 2>&1
  cmp -s "$OWNED" "$HOME/owned.1"
  cmp -s "$CONF" "$HOME/conf.1"
}

@test "another flavour re-renders the header and the colours" {
  load_adapter
  terminal_apply latte >/dev/null 2>&1
  assert_contains "$(head -n 1 "$OWNED")" "(latte)"
  [ "$(owned_values background foreground)" = "#eff1f5 | #4c4f69" ]
}

@test "a dry run writes nothing and says what it would do" {
  load_adapter
  export NEKOSHELL_DRY_RUN=1
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ ! -e "$OWNED" ]
  [ ! -e "$CONF" ]
  assert_contains "$output" "would render $OWNED (mocha)"
  assert_contains "$output" "would add '$INCLUDE'"
}

@test "terminal_apply re-applies a stored background" {
  load_adapter
  config_set background "$HOME/wall.png"
  config_set background_opacity 0.8
  status=0; output="$(terminal_apply latte 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(owned_values background-image background-image-opacity background-image-fit)" = "$HOME/wall.png | 0.8 | cover" ]
}

@test "terminal_apply falls back to 0.85 for a stored opacity out of range" {
  load_adapter
  config_set background "$HOME/wall.png"
  config_set background_opacity 1.5
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "not between 0 and 1"
  [ "$(owned_values background-image-opacity)" = "0.85" ]
}

# --- terminal_background -----------------------------------------------------

@test "terminal_background writes the image lines and records the path" {
  load_adapter
  status=0; output="$(terminal_background "$HOME/wall.png" 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(owned_values background-image background-image-opacity background-image-fit)" = "$HOME/wall.png | 0.85 | cover" ]
  [ "$(config_get background)" = "$HOME/wall.png" ]
  [ "$(config_get background_opacity)" = "0.85" ]
  assert_contains "$output" "does not exist yet"
}

@test "terminal_background honours an explicit opacity" {
  load_adapter
  status=0; output="$(terminal_background "$HOME/wall.png" 0.5 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(owned_values background-image-opacity)" = "0.5" ]
}

@test "terminal_background makes a relative path absolute" {
  load_adapter
  printf 'png\n' > "$HOME/wall.png"
  cd "$HOME"
  status=0; output="$(terminal_background wall.png 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  # Ghostty resolves a relative background-image against its own working
  # directory, so a relative one would point at nothing.
  [ "$(owned_values background-image)" = "$HOME/wall.png" ]
}

@test "terminal_background refuses an opacity that is not between 0 and 1" {
  load_adapter
  terminal_background none >/dev/null 2>&1
  before="$(cat "$OWNED")"
  status=0; output="$(terminal_background "$HOME/wall.png" 1.5 2>&1)" || status=$?
  [ "$status" -eq 1 ]
  assert_contains "$output" "opacity must be between 0 and 1"
  status=0; output="$(terminal_background "$HOME/wall.png" abc 2>&1)" || status=$?
  [ "$status" -eq 1 ]
  # Refused before anything was written.
  [ "$(cat "$OWNED")" = "$before" ]
  status=0; output="$(terminal_background "$HOME/wall.png" 1 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(owned_values background-image-opacity)" = "1" ]
}

@test "terminal_background none clears the image lines and the record" {
  load_adapter
  terminal_background "$HOME/wall.png" >/dev/null 2>&1
  status=0; output="$(terminal_background none 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_not_contains "$(cat "$OWNED")" "background-image"
  [ -z "$(config_get background)" ]
}

@test "a dry run of terminal_background writes nothing and records nothing" {
  load_adapter
  export NEKOSHELL_DRY_RUN=1
  status=0; output="$(terminal_background "$HOME/wall.png" 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ ! -e "$OWNED" ]
  status=0; config_get background >/dev/null 2>&1 || status=$?
  [ "$status" -ne 0 ]
  assert_contains "$output" "would render"
}

# --- terminal_panel ----------------------------------------------------------

@test "terminal_panel pops up inside tmux and runs inline with a hotkey hint outside" {
  load_adapter
  status=0; output="$(TMUX=1 terminal_panel echo hi 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "tmux display-popup"
  status=0; output="$(terminal_panel echo hi 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "toggle the panel"
  assert_contains "$output" "hi"
}

# --- the zsh hook ------------------------------------------------------------

@test "zsh.zsh is zsh-clean and only execs the player in a quick terminal" {
  zsh -n "$REPO_ROOT/terminals/ghostty/zsh.zsh"
  # A fake nekoshell on PATH records what the hook exec'd, which is the only
  # observable the hook has: after exec there is no shell left to ask.
  mkdir -p "$HOME/bin"
  printf '#!/bin/sh\necho "nekoshell $* panel=${NEKOSHELL_PANEL:-}"\n' > "$HOME/bin/nekoshell"
  chmod +x "$HOME/bin/nekoshell"
  hook="$REPO_ROOT/terminals/ghostty/zsh.zsh"
  # Not interactive: the hook is a no-op.
  out="$(GHOSTTY_QUICK_TERMINAL=1 PATH="$HOME/bin:$PATH" zsh -c "source $hook; echo shell")"
  [ "$out" = "shell" ]
  # Interactive and in the quick terminal: the shell becomes the player.
  out="$(GHOSTTY_QUICK_TERMINAL=1 PATH="$HOME/bin:$PATH" zsh -i -c "source $hook; echo shell" 2>/dev/null)"
  [ "$out" = "nekoshell music --here panel=1" ]
  # Interactive but not the quick terminal: still a shell.
  out="$(PATH="$HOME/bin:$PATH" zsh -i -c "source $hook; echo shell" 2>/dev/null)"
  [ "$out" = "shell" ]
  # A shell the player opened inside the quick terminal stays a shell.
  out="$(GHOSTTY_QUICK_TERMINAL=1 NEKOSHELL_PANEL=1 PATH="$HOME/bin:$PATH" zsh -i -c "source $hook; echo shell" 2>/dev/null)"
  [ "$out" = "shell" ]
  # ghostty_quick_terminal = "shell" in the toml keeps a plain shell.
  printf 'ghostty_quick_terminal = "shell"\n' >> "$HOME/.config/nekoshell/nekoshell.toml"
  out="$(GHOSTTY_QUICK_TERMINAL=1 NEKOSHELL_CONFIG="$HOME/.config/nekoshell" PATH="$HOME/bin:$PATH" zsh -i -c "source $hook; echo shell" 2>/dev/null)"
  [ "$out" = "shell" ]
  # The environment wins over the toml.
  out="$(GHOSTTY_QUICK_TERMINAL=1 NEKOSHELL_GHOSTTY_QUICK=music NEKOSHELL_CONFIG="$HOME/.config/nekoshell" PATH="$HOME/bin:$PATH" zsh -i -c "source $hook; echo shell" 2>/dev/null)"
  [ "$out" = "nekoshell music --here panel=1" ]
}

# --- the doctor and the commands --------------------------------------------

@test "doctor fails the config, include and hotkey rows before anything is applied" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  run "$NK" doctor
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +ghostty config +missing'
  assert_matches "$output" 'fail +ghostty include'
  assert_matches "$output" 'warn +ghostty font +no font to read'
  assert_matches "$output" 'fail +ghostty hotkey'
}

@test "doctor reports the config, include, font and hotkey rows after an apply" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  "$NK" terminal apply >/dev/null 2>&1
  run "$NK" doctor
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +ghostty config'
  assert_matches "$output" 'ok +ghostty include'
  assert_matches "$output" 'ok +ghostty font +JetBrainsMono Nerd Font'
  # The permission that makes a global keybind work is granted in System
  # Settings and cannot be read from here, so the row is a warning, not a pass.
  assert_matches "$output" 'warn +ghostty hotkey +.*Accessibility'
}

@test "doctor fails the config row when the file is another flavour, and the font row when it names another font" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  "$NK" terminal apply >/dev/null 2>&1
  sed -i '' -e '1s/(mocha)/(latte)/' -e 's/^font-family = .*/font-family = Menlo/' "$OWNED"
  run "$NK" doctor
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +ghostty config +rendered for another flavour'
  assert_matches "$output" 'fail +ghostty font +Menlo is not JetBrainsMono Nerd Font'
}

@test "doctor fails the include row when the line is gone from the main config" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  "$NK" terminal apply >/dev/null 2>&1
  printf 'font-size = 18\n' > "$CONF"
  run "$NK" doctor
  [ "$status" -eq 1 ]
  assert_matches "$output" 'ok +ghostty config'
  assert_matches "$output" 'fail +ghostty include'
}

@test "nekoshell terminal use ghostty records the terminal and renders the config" {
  printf 'root = "%s"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  run "$NK" terminal use ghostty
  [ "$status" -eq 0 ]
  [ -f "$OWNED" ]
  grep -qxF "$INCLUDE" "$CONF"
  grep -q '^terminal = "ghostty"$' "$HOME/.config/nekoshell/nekoshell.toml"
  run "$NK" terminal capabilities
  assert_contains "$output" "hotkey"
}

@test "nekoshell theme latte re-renders the config in latte" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  run "$NK" theme latte
  [ "$status" -eq 0 ]
  assert_contains "$(head -n 1 "$OWNED")" "(latte)"
  run grep -x 'background = #eff1f5' "$OWNED"
  [ "$status" -eq 0 ]
}

# --- terminal_remove ---------------------------------------------------------

@test "terminal_remove deletes the owned file and the config it created" {
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  [ -f "$OWNED" ]; [ -f "$CONF" ]
  rc=0; out="$(terminal_remove 2>&1)" || rc=$?
  [ "$rc" -eq 0 ]
  [ ! -e "$OWNED" ]
  [ ! -e "$CONF" ]
  assert_contains "$out" "removed '$INCLUDE'"
}

@test "terminal_remove strips only the tagged pair from a config with the user's own lines" {
  load_adapter
  printf 'font-size = 18\n' > "$CONF"
  terminal_apply mocha >/dev/null 2>&1
  printf 'theme = Dracula\n' >> "$CONF"
  terminal_remove >/dev/null 2>&1
  [ "$(cat "$CONF")" = "font-size = 18
theme = Dracula" ]
}

@test "terminal_remove leaves an include line the user wrote without the marker" {
  load_adapter
  printf '%s\n# nekoshell\n' "$INCLUDE" > "$CONF"
  terminal_apply mocha >/dev/null 2>&1
  terminal_remove >/dev/null 2>&1
  # Their line stays; a lone marker not followed by our include stays too.
  [ "$(cat "$CONF")" = "$INCLUDE
# nekoshell" ]
}

@test "terminal_remove is a no-op on a config without our lines, and does nothing in a dry run" {
  load_adapter
  printf 'font-size = 18\n' > "$CONF"
  rc=0; terminal_remove >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 0 ]
  [ "$(cat "$CONF")" = "font-size = 18" ]
  terminal_apply mocha >/dev/null 2>&1
  export NEKOSHELL_DRY_RUN=1
  out="$(terminal_remove 2>&1)"
  [ -f "$OWNED" ]
  grep -qxF "$INCLUDE" "$CONF"
  assert_contains "$out" "would remove"
}

@test "uninstall removes the Ghostty config and restores the original main config" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  printf 'font-size = 18\n' > "$CONF"
  "$NK" terminal apply >/dev/null 2>&1
  grep -qxF "$INCLUDE" "$CONF"
  run "$NK" uninstall --yes
  [ "$status" -eq 0 ]
  [ ! -e "$OWNED" ]
  [ "$(cat "$CONF")" = "font-size = 18" ]
}

# --- Ghostty's own validator -------------------------------------------------

@test "the rendered config and the main config with the include pass ghostty +validate-config" {
  bin="$(ghostty_bin)"
  [ -n "$bin" ] || skip "ghostty is not installed on this Mac"
  load_adapter
  config_set background "$HOME/wall.png"
  terminal_apply mocha >/dev/null 2>&1
  rc=0; out="$("$bin" +validate-config --config-file="$OWNED" 2>&1)" || rc=$?
  echo "$out"
  [ "$rc" -eq 0 ]
  rc=0; out="$("$bin" +validate-config --config-file="$CONF" 2>&1)" || rc=$?
  echo "$out"
  [ "$rc" -eq 0 ]
  # The validator does notice a broken include, so the pass above means the
  # relative path resolved against the config's own directory.
  printf 'config-file = missing\n' > "$HOME/broken"
  rc=0; "$bin" +validate-config --config-file="$HOME/broken" >/dev/null 2>&1 || rc=$?
  [ "$rc" -ne 0 ]
}
