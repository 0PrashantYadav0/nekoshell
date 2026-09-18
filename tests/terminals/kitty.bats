#!/usr/bin/env bats
# The kitty terminal adapter: the two rendered files, the include line in
# kitty.conf, the adapter contract on top of them, and the rows it reports to
# the doctor.
load ../helpers

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_ROOT="$REPO_ROOT"
  # The real adapters directory, not the fixtures one: kitty is the adapter
  # under test. Unset rather than pointed at terminals/, so core/lib/terminal.sh
  # derives it the way a real run does.
  unset NEKOSHELL_TERMINALS_DIR
  unset NEKOSHELL_PANEL TMUX KITTY_LISTEN_ON KITTY_CONFIG_DIRECTORY FAKE_KITTEN_RC_FAILS FAKE_SIPS_FAILS
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "kitty"\nterminals = ["kitty"]\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  KDIR="$HOME/.config/kitty"
  CONF="$KDIR/kitty.conf"
  NCONF="$KDIR/nekoshell.conf"
  PCONF="$KDIR/nekoshell-panel.conf"
  PNG="$HOME/.local/share/nekoshell/kitty-background.png"
}
teardown() { teardown_tmp_home; }

# Sourcing the libraries pulls in log.sh's run(), which shadows bats' own run()
# for the rest of the test process; these tests capture with $( ) instead, the
# way tests/core/terminal.bats does.
load_adapter() {
  local l
  for l in log paths backup config theme terminal; do
    # shellcheck source=/dev/null
    source "$REPO_ROOT/core/lib/$l.sh"
  done
  terminal_load kitty
}

# The value of OPTION in nekoshell.conf, or nothing.
conf_value() { sed -n "s/^$1[[:space:]]*//p" "$NCONF" | head -1; }

# The real kitty, if this Mac has one, found on the real PATH rather than the
# fakes dir the tests put in front of it.
real_kitty() { PATH=/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin command -v kitty; }

# --- the adapter contract ----------------------------------------------------

@test "name, capabilities and font" {
  load_adapter
  [ "$(terminal_name)" = "kitty" ]
  [ "$(terminal_capabilities)" = "truecolor images background panel hotkey" ]
  [ "$(terminal_font_name)" = "JetBrainsMono Nerd Font" ]
}

@test "terminal_detect is true under KITTY_WINDOW_ID or TERM=xterm-kitty" {
  load_adapter
  status=0; ( KITTY_WINDOW_ID=1 terminal_detect ) || status=$?
  [ "$status" -eq 0 ]
  status=0; ( TERM=xterm-kitty terminal_detect ) || status=$?
  [ "$status" -eq 0 ]
  status=0; ( TERM_PROGRAM=iTerm.app terminal_detect ) || status=$?
  [ "$status" -eq 1 ]
  status=0; ( terminal_detect ) || status=$?
  [ "$status" -eq 1 ]
}

@test "terminal_installed follows the app bundle or the kitty command" {
  load_adapter
  # $HOME is the throwaway one, so this never sees the developer's own kitty
  # unless it really is installed in /Applications.
  if [ -e /Applications/kitty.app ]; then skip "kitty is installed in /Applications on this Mac"; fi
  status=0; ( PATH=/usr/bin:/bin; terminal_installed ) || status=$?
  [ "$status" -eq 1 ]
  mkdir -p "$HOME/Applications/kitty.app"
  status=0; ( PATH=/usr/bin:/bin; terminal_installed ) || status=$?
  [ "$status" -eq 0 ]
}

# --- terminal_apply ----------------------------------------------------------

@test "terminal_apply renders both files and puts the include line in kitty.conf" {
  load_adapter
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ -f "$NCONF" ]
  [ -f "$PCONF" ]
  # The marker is a line of its own above the include: kitty takes everything
  # after `include` as the file name, a trailing comment included.
  [ "$(cat "$CONF")" = "# nekoshell
include nekoshell.conf" ]
  assert_contains "$output" "added 'include nekoshell.conf'"
  assert_not_contains "$output" "kitten @"
}

@test "nekoshell.conf carries the header, the font, the colours and the panel mapping" {
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  assert_matches "$(head -1 "$NCONF")" '^# nekoshell .*flavour mocha'
  [ "$(conf_value font_family)" = "$(terminal_font_name)" ]
  [ "$(conf_value font_size)" = "15" ]
  [ "$(conf_value background)" = "#1e1e2e" ]
  [ "$(conf_value foreground)" = "#cdd6f4" ]
  [ "$(conf_value color0)" = "#45475a" ]
  [ "$(conf_value color5)" = "#f5c2e7" ]
  [ "$(conf_value color15)" = "#bac2de" ]
  [ "$(conf_value cursor)" = "#f5e0dc" ]
  [ "$(conf_value selection_background)" = "#585b70" ]
  [ "$(conf_value active_tab_background)" = "#cba6f7" ]
  [ "$(conf_value tab_bar_background)" = "#11111b" ]
  [ "$(conf_value window_padding_width)" = "12" ]
  [ "$(conf_value macos_option_as_alt)" = "yes" ]
  [ "$(conf_value allow_remote_control)" = "socket-only" ]
  [ "$(conf_value listen_on)" = "unix:/tmp/kitty-nekoshell" ]
  [ "$(conf_value 'map alt+m')" = "launch --type=background kitten quick-access-terminal --config=\"$PCONF\" /usr/bin/env NEKOSHELL_PANEL=1 \"$REPO_ROOT/bin/nekoshell\" music --here" ]
  # No placeholder survives the render.
  assert_not_contains "$(cat "$NCONF")" "@@"
}

@test "the panel config docks a 60-column terminal on the right that reads kitty.conf" {
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  local panel
  panel="$(cat "$PCONF")"
  assert_matches "$(head -1 "$PCONF")" '^# nekoshell .*flavour mocha'
  assert_matches "$panel" $'\nedge +right\n'
  assert_matches "$panel" $'\ncolumns +60\n'
  assert_matches "$panel" $'\nhide_on_focus_loss +yes\n'
  assert_matches "$panel" $'\nstart_as_hidden +no\n'
  assert_matches "$panel" $'\nbackground_opacity +0.95\n'
  assert_contains "$panel" "kitty_conf     $CONF"
  assert_contains "$panel" "kitty_override background=#1e1e2e"
  assert_not_contains "$panel" "@@"
}

@test "another flavour renders that palette into both files" {
  load_adapter
  terminal_apply latte >/dev/null 2>&1
  assert_matches "$(head -1 "$NCONF")" 'flavour latte'
  [ "$(conf_value background)" = "#eff1f5" ]
  [ "$(conf_value foreground)" = "#4c4f69" ]
  assert_contains "$(cat "$PCONF")" "kitty_override background=#eff1f5"
}

@test "terminal_apply twice yields the same files and one include line" {
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  cp "$NCONF" "$HOME/first.conf"
  cp "$PCONF" "$HOME/first-panel.conf"
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  cmp -s "$NCONF" "$HOME/first.conf"
  cmp -s "$PCONF" "$HOME/first-panel.conf"
  [ "$(grep -c 'include nekoshell.conf' "$CONF")" -eq 1 ]
  [ "$(grep -c '# nekoshell' "$CONF")" -eq 1 ]
  assert_not_contains "$output" "added"
}

@test "a user's kitty.conf keeps its lines, gets the include once, and is backed up once" {
  load_adapter
  mkdir -p "$KDIR"
  # No trailing newline: the marker must not land on the end of this line.
  printf 'font_size 20\nbackground_opacity 0.9' > "$CONF"
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(cat "$CONF")" = "font_size 20
background_opacity 0.9
# nekoshell
include nekoshell.conf" ]
  assert_contains "$output" "backing up your .config/kitty/kitty.conf"
  local sets
  sets="$(find "$HOME/.local/share/nekoshell/backup" -name manifest.txt | wc -l | tr -d ' ')"
  [ "$sets" = "1" ]
  [ "$(cat "$HOME"/.local/share/nekoshell/backup/*/.config/kitty/kitty.conf)" = "font_size 20
background_opacity 0.9" ]
  # The second apply finds the include in place: no edit, no second backup.
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  assert_not_contains "$output" "backing up"
  [ "$(grep -c 'include nekoshell.conf' "$CONF")" -eq 1 ]
}

@test "a dry run renders nothing and edits nothing" {
  load_adapter
  mkdir -p "$KDIR"
  printf 'font_size 20\n' > "$CONF"
  export NEKOSHELL_DRY_RUN=1
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "would render $NCONF"
  assert_contains "$output" "would render $PCONF"
  assert_contains "$output" "would add 'include nekoshell.conf'"
  [ ! -e "$NCONF" ]
  [ ! -e "$PCONF" ]
  [ "$(cat "$CONF")" = "font_size 20" ]
  status=0; output="$(terminal_background "$HOME/wall.png" 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "would set background_image $HOME/wall.png"
  [ ! -e "$NCONF" ]
}

@test "terminal_apply reloads the kitty this shell runs in, and only hints when it cannot" {
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  export KITTY_WINDOW_ID=1 KITTY_LISTEN_ON=unix:/tmp/kitty-nekoshell-42
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "kitten @ --to unix:/tmp/kitty-nekoshell-42 load-config"
  assert_not_contains "$output" "ctrl+shift+f5"
  # A kitty started before remote control was configured refuses; that is a
  # hint for the human, not a failed apply.
  export FAKE_KITTEN_RC_FAILS=1
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "ctrl+shift+f5"
  # No socket to talk to: say how to reload by hand.
  unset KITTY_LISTEN_ON
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "kitten @"
  assert_contains "$output" "ctrl+shift+f5"
}

# --- terminal_background -----------------------------------------------------

@test "terminal_background writes the image lines and records the choice" {
  load_adapter
  printf 'png\n' > "$HOME/wall.png"
  status=0; output="$(terminal_background "$HOME/wall.png" 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(conf_value background_image)" = "$HOME/wall.png" ]
  [ "$(conf_value background_image_layout)" = "scaled" ]
  # The default opacity is 0.85; kitty's tint is the opposite, 0.15.
  [ "$(conf_value background_tint)" = "0.15" ]
  [ "$(conf_value background_opacity)" = "1" ]
  [ "$(config_get background)" = "$HOME/wall.png" ]
  [ "$(config_get background_opacity)" = "0.85" ]
  assert_not_contains "$output" "sips"
}

@test "terminal_background converts anything that is not a PNG with sips" {
  load_adapter
  printf 'jpg\n' > "$HOME/wall.jpg"
  status=0; output="$(terminal_background "$HOME/wall.jpg" 0.7 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "sips -s format png $HOME/wall.jpg --out $PNG"
  [ -f "$PNG" ]
  [ "$(conf_value background_image)" = "$PNG" ]
  [ "$(conf_value background_tint)" = "0.3" ]
  # The original is what is recorded, so a later switch to another terminal
  # starts from the user's file, not from kitty's copy.
  [ "$(config_get background)" = "$HOME/wall.jpg" ]
  # A conversion newer than its source is not redone.
  status=0; output="$(terminal_apply latte 2>&1)" || status=$?
  assert_not_contains "$output" "sips"
  [ "$(conf_value background_image)" = "$PNG" ]
}

@test "terminal_background makes a relative path absolute" {
  load_adapter
  printf 'png\n' > "$HOME/wall.png"
  cd "$HOME"
  status=0; output="$(terminal_background wall.png 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  # kitty resolves a relative background_image against its own config
  # directory, so a relative one would point at nothing.
  [ "$(conf_value background_image)" = "$HOME/wall.png" ]
}

@test "terminal_background refuses an opacity that is not between 0 and 1" {
  load_adapter
  terminal_background none >/dev/null 2>&1
  cp "$NCONF" "$HOME/before.conf"
  status=0; output="$(terminal_background "$HOME/wall.png" 1.5 2>&1)" || status=$?
  [ "$status" -eq 1 ]
  assert_contains "$output" "opacity must be between 0 and 1"
  status=0; output="$(terminal_background "$HOME/wall.png" abc 2>&1)" || status=$?
  [ "$status" -eq 1 ]
  # Refused before anything was written.
  cmp -s "$NCONF" "$HOME/before.conf"
  status=0; output="$(terminal_background "$HOME/wall.png" 1 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  # A fully opaque image is tint 0: none of the background colour over it.
  [ "$(conf_value background_tint)" = "0" ]
  status=0; output="$(terminal_background "$HOME/wall.png" 0.5 2>&1)" || status=$?
  [ "$(conf_value background_tint)" = "0.5" ]
}

@test "terminal_background none clears the image lines and the recorded choice" {
  load_adapter
  terminal_background "$HOME/wall.png" >/dev/null 2>&1
  status=0; output="$(terminal_background none 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ -z "$(conf_value background_image)" ]
  [ -z "$(conf_value background_tint)" ]
  [ -z "$(config_get background)" ]
  [ "$(conf_value background)" = "#1e1e2e" ]
}

@test "terminal_apply re-applies a stored background, and falls back on a bad opacity" {
  load_adapter
  config_set background "$HOME/wall.png"
  config_set background_opacity 0.8
  status=0; output="$(terminal_apply latte 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(conf_value background_image)" = "$HOME/wall.png" ]
  [ "$(conf_value background_tint)" = "0.2" ]
  config_set background_opacity 7
  status=0; output="$(terminal_apply latte 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "not between 0 and 1"
  [ "$(conf_value background_tint)" = "0.15" ]
}

# --- terminal_panel ----------------------------------------------------------

@test "terminal_panel pops up inside tmux, toggles the kitten inside kitty, runs inline elsewhere" {
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  status=0; output="$(TMUX=1 KITTY_WINDOW_ID=1 terminal_panel echo hi 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "tmux display-popup"
  assert_not_contains "$output" "kitten"
  status=0; output="$(KITTY_WINDOW_ID=1 terminal_panel echo hi 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "kitten quick-access-terminal --config $PCONF echo hi"
  assert_contains "$output" "alt+m"
  status=0; output="$(terminal_panel echo hi 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$output" = "hi" ]
}

@test "terminal_panel inside kitty runs inline when the panel config is missing" {
  load_adapter
  status=0; output="$(KITTY_WINDOW_ID=1 terminal_panel echo hi 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "kitten"
  assert_contains "$output" "nekoshell terminal apply"
  assert_contains "$output" "hi"
}

# --- terminal_remove ---------------------------------------------------------

@test "terminal_remove deletes the owned files and strips only the include lines" {
  load_adapter
  mkdir -p "$KDIR"
  # The user's own "# nekoshell" comment, not followed by the include, stays.
  printf '# nekoshell\n# my notes\nfont_size 20\n' > "$CONF"
  printf 'jpg\n' > "$HOME/wall.jpg"
  terminal_background "$HOME/wall.jpg" >/dev/null 2>&1
  [ -f "$PNG" ]
  status=0; output="$(terminal_remove 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ ! -e "$NCONF" ]
  [ ! -e "$PCONF" ]
  [ ! -e "$PNG" ]
  [ "$(cat "$CONF")" = "# nekoshell
# my notes
font_size 20" ]
  status=0; output="$(terminal_remove 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(cat "$CONF")" = "# nekoshell
# my notes
font_size 20" ]
}

@test "terminal_remove deletes a kitty.conf that nekoshell created and nothing else filled" {
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  [ -f "$CONF" ]
  status=0; output="$(terminal_remove 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ ! -e "$CONF" ]
  assert_contains "$output" "removed the now empty"
}

@test "a dry-run remove leaves everything in place" {
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  export NEKOSHELL_DRY_RUN=1
  status=0; output="$(terminal_remove 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "would remove 'include nekoshell.conf'"
  [ -f "$NCONF" ]
  [ -f "$PCONF" ]
  [ -f "$CONF" ]
}

# --- the doctor and the commands --------------------------------------------

@test "doctor fails the config, include and panel rows before anything is applied" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  run "$NK" doctor
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +kitty config +missing'
  assert_matches "$output" 'fail +kitty include'
  assert_matches "$output" 'warn +kitty font +no font to read'
  assert_matches "$output" 'fail +kitty panel +missing'
}

@test "doctor passes every kitty row after an apply" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  "$NK" terminal apply >/dev/null 2>&1
  run "$NK" doctor
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +kitty config +.*nekoshell.conf \(mocha\)'
  assert_matches "$output" 'ok +kitty include +.*kitty.conf'
  assert_matches "$output" 'ok +kitty font +JetBrainsMono Nerd Font'
  assert_matches "$output" 'ok +kitty panel +.*nekoshell-panel.conf'
}

@test "doctor fails the config row when the file was rendered for another flavour" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  "$NK" terminal apply >/dev/null 2>&1
  sed -i '' 's/^theme_resolved = "mocha"/theme_resolved = "latte"/' "$HOME/.config/nekoshell/nekoshell.toml"
  run "$NK" doctor
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +kitty config +rendered for mocha, theme is latte'
}

@test "doctor fails the font and include rows when someone edited them" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  "$NK" terminal apply >/dev/null 2>&1
  sed -i '' 's/^font_family .*/font_family      Menlo/' "$HOME/.config/kitty/nekoshell.conf"
  printf 'font_size 20\n' > "$HOME/.config/kitty/kitty.conf"
  run "$NK" doctor
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +kitty font +Menlo is not JetBrainsMono Nerd Font'
  assert_matches "$output" "fail +kitty include +'include nekoshell.conf' missing"
}

@test "nekoshell terminal use kitty records the terminal and writes the files" {
  printf 'root = "%s"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  run "$NK" terminal use kitty
  [ "$status" -eq 0 ]
  [ -f "$NCONF" ]
  [ -f "$PCONF" ]
  grep -q 'include nekoshell.conf' "$CONF"
  grep -q '^terminal = "kitty"$' "$HOME/.config/nekoshell/nekoshell.toml"
  run "$NK" terminal capabilities
  assert_contains "$output" "hotkey"
}

@test "nekoshell theme latte re-renders both files in latte" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  run "$NK" theme latte
  [ "$status" -eq 0 ]
  assert_matches "$(head -1 "$NCONF")" 'flavour latte'
  [ "$(sed -n 's/^background[[:space:]]*//p' "$NCONF" | head -1)" = "#eff1f5" ]
  assert_matches "$(head -1 "$PCONF")" 'flavour latte'
}

@test "uninstall removes the kitty files and the include line" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  mkdir -p "$KDIR"
  printf 'font_size 20\n' > "$CONF"
  "$NK" terminal apply >/dev/null 2>&1
  [ -f "$NCONF" ]
  grep -q 'include nekoshell.conf' "$CONF"
  run "$NK" uninstall --yes
  [ "$status" -eq 0 ]
  [ ! -e "$NCONF" ]
  [ ! -e "$PCONF" ]
  # The user's file is back as it was, from the backup or from the strip.
  [ "$(cat "$CONF")" = "font_size 20" ]
}

# --- the real kitty ----------------------------------------------------------

@test "the real kitty parses the rendered config with no errors" {
  if ! real_kitty >/dev/null 2>&1; then skip "kitty is not installed"; fi
  load_adapter
  printf 'png\n' > "$HOME/wall.png"
  terminal_apply mocha >/dev/null 2>&1
  terminal_background "$HOME/wall.png" 0.7 >/dev/null 2>&1
  # kitty's own parser, headless: it logs every unknown option, bad value or
  # missing include on stderr, so an empty stderr is a clean parse.
  local script err out
  script='
import sys
from kitty.config import load_config
o = load_config(sys.argv[1])
print(o.font_family.created_from_string, o.font_size, o.background, o.color5)
print(o.background_image[0], o.background_tint, o.macos_option_as_alt, o.allow_remote_control)
maps = [d.definition for km in o.keyboard_modes.values() for v in km.keymap.values() for d in v if "quick-access-terminal" in d.definition]
print(len(maps), maps[0] if maps else "")
'
  err="$(PATH=/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin kitty +runpy "$script" "$CONF" 2>&1 >/dev/null)"
  [ -z "$err" ]
  out="$(PATH=/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin kitty +runpy "$script" "$CONF" 2>/dev/null)"
  assert_contains "$out" "JetBrainsMono Nerd Font 15.0 Color(30, 30, 46) Color(245, 194, 231)"
  assert_contains "$out" "$HOME/wall.png 0.3"
  assert_contains "$out" "1 launch --type=background kitten quick-access-terminal --config=\"$PCONF\""
}

@test "the panel config uses only options the quick-access kitten documents" {
  local sample
  sample="$(ls /Applications/kitty.app/Contents/Resources/doc/kitty/html/_downloads/*/quick_access_terminal.conf 2>/dev/null | head -1)"
  if [ -z "$sample" ]; then skip "kitty's sample quick_access_terminal.conf is not on this Mac"; fi
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  local key bad=""
  while IFS= read -r key; do
    # The sample lists every option as "# name default", or "# name" alone
    # when the default is empty (kitty_conf is one of those).
    grep -Eq "^# $key( |$)" "$sample" || bad="$bad $key"
  done < <(sed -n 's/^\([a-z_]*\) .*/\1/p' "$PCONF")
  if [ -n "$bad" ]; then echo "options the kitten does not know:$bad" >&2; false; fi
}

@test "latte renders a dark ANSI black, so black text stays readable on the light base" {
  load_adapter
  terminal_apply latte >/dev/null 2>&1
  [ "$(conf_value background)" = "#eff1f5" ]
  [ "$(conf_value color0)" = "#5c5f77" ]
  [ "$(conf_value color8)" = "#6c6f85" ]
  [ "$(conf_value color7)" = "#acb0be" ]
}
