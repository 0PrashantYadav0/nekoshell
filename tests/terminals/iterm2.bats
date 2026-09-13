#!/usr/bin/env bats
# The iTerm2 terminal adapter: the dynamic profile generator, the adapter
# contract on top of it, and the rows it reports to the doctor.
load ../helpers

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_ROOT="$REPO_ROOT"
  # The real adapters directory, not the fixtures one: iterm2 is the adapter
  # under test. Unset rather than pointed at terminals/, so core/lib/terminal.sh
  # derives it the way a real run does.
  unset NEKOSHELL_TERMINALS_DIR
  unset NEKOSHELL_PANEL TMUX TERM_PROGRAM FAKE_ITERM_RUNNING
  export TERM=xterm-256color
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "iterm2"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  GEN="$REPO_ROOT/terminals/iterm2/build-profiles.py"
  OUT="$HOME/nekoshell.json"
  PROF="$HOME/Library/Application Support/iTerm2/DynamicProfiles/nekoshell.json"
}
teardown() { teardown_tmp_home; }

# Sourcing the libraries pulls in log.sh's run(), which shadows bats' own run()
# for the rest of the test process; these tests capture with $( ) instead, the
# way tests/core/terminal.bats does.
load_adapter() {
  local l
  for l in log paths config theme terminal; do
    # shellcheck source=/dev/null
    source "$REPO_ROOT/core/lib/$l.sh"
  done
  terminal_load iterm2
}

# One line per profile, joined: the tests that read the profile file after
# load_adapter cannot use bats' run() (log.sh's own run() has shadowed it), so
# they compare a single captured string instead of ${lines[@]}.
profile_backgrounds() {
  python3 - "$PROF" <<'PY'
import json, sys
out = []
for p in json.load(open(sys.argv[1]))['Profiles']:
    if 'Background Image Location' in p:
        out.append(f"{p['Background Image Location']} {round(p.get('Blend', -1), 4)}")
    else:
        out.append(f"none {'Blend' in p}")
print(" | ".join(out))
PY
}

# --- the generator -----------------------------------------------------------

@test "generator writes two profiles with fixed guids" {
  run python3 "$GEN" --root "$REPO_ROOT" --out "$OUT"
  [ "$status" -eq 0 ]
  run python3 -c "import json,sys; d=json.load(open('$OUT')); print(len(d['Profiles'])); print(d['Profiles'][0]['Guid']); print(d['Profiles'][1]['Guid'])"
  [ "${lines[0]}" = "2" ]
  [ "${lines[1]}" = "4E4B4F53-4845-4C4C-0001-000000000001" ]
  [ "${lines[2]}" = "4E4B4F53-4845-4C4C-0002-000000000002" ]
}

@test "main profile carries the theme, font and window settings" {
  python3 "$GEN" --root "$REPO_ROOT" --out "$OUT"
  run python3 - "$OUT" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))['Profiles'][0]
bg=p['Background Color']
print(p['Name'], p['Normal Font'], p['ASCII Ligatures'], p['Window Type'], p['Transparency'], p['Blur'], p['Blur Radius'], p['Use Cursor Guide'], p['Show Status Bar'])
print(round(bg['Red Component']*255), round(bg['Green Component']*255), round(bg['Blue Component']*255), bg['Color Space'])
print(round(p['Ansi 5 Color']['Red Component']*255), round(p['Ansi 5 Color']['Green Component']*255), round(p['Ansi 5 Color']['Blue Component']*255))
PY
  [ "${lines[0]}" = "nekoshell JetBrainsMonoNF-Regular 15 True 0 0.1 True 24 True True" ]
  [ "${lines[1]}" = "30 30 46 sRGB" ]
  [ "${lines[2]}" = "245 194 231" ]
}

@test "--flavor picks another Catppuccin palette from core/theme/palettes.json" {
  python3 "$GEN" --root "$REPO_ROOT" --out "$OUT" --flavor latte
  run python3 - "$OUT" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))['Profiles'][0]
bg=p['Background Color']; fg=p['Foreground Color']
print(round(bg['Red Component']*255), round(bg['Green Component']*255), round(bg['Blue Component']*255))
print(round(fg['Red Component']*255), round(fg['Green Component']*255), round(fg['Blue Component']*255))
PY
  [ "${lines[0]}" = "239 241 245" ]
  [ "${lines[1]}" = "76 79 105" ]
}

@test "an unknown flavour is refused instead of written" {
  run python3 "$GEN" --root "$REPO_ROOT" --out "$OUT" --flavor dracula
  [ "$status" -ne 0 ]
  [ ! -f "$OUT" ]
}

@test "panel profile is a right-docked hotkey window running nekoshell music --here" {
  python3 "$GEN" --root "$REPO_ROOT" --out "$OUT" --window-type 6
  run python3 - "$OUT" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))['Profiles'][1]
print(p['Name'], p['Has Hotkey'], p['HotKey Key Code'], p['HotKey Characters'], p['HotKey Characters Ignoring Modifiers'], p['HotKey Modifier Flags'])
print(p['HotKey Window Animates'], p['HotKey Window AutoHides'], p['HotKey Window Floats'], p['HotKey Window Reopens On Activation'], p['Window Type'], p['Space'], p['Columns'], p['Rows'])
print(p['Custom Command'], p['Command'])
PY
  [ "${lines[0]}" = "nekoshell panel True 46 µ m 524288" ]
  [ "${lines[1]}" = "True True True False 6 -1 60 40" ]
  [ "${lines[2]}" = "Yes /usr/bin/env NEKOSHELL_PANEL=1 $REPO_ROOT/bin/nekoshell music --here" ]
}

@test "without the background flags neither profile carries a background key" {
  python3 "$GEN" --root "$REPO_ROOT" --out "$OUT"
  run python3 - "$OUT" <<'PY'
import json,sys
for p in json.load(open(sys.argv[1]))['Profiles']:
    print('Background Image Location' in p, 'Blend' in p)
PY
  [ "${lines[0]}" = "False False" ]
  [ "${lines[1]}" = "False False" ]
}

@test "--background and --blend set both profiles, and an empty --background clears them" {
  python3 "$GEN" --root "$REPO_ROOT" --out "$OUT" --background /tmp/wall.png --blend 0.15
  run python3 - "$OUT" <<'PY'
import json,sys
for p in json.load(open(sys.argv[1]))['Profiles']:
    print(p['Background Image Location'], p['Blend'], type(p['Blend']).__name__)
PY
  [ "${lines[0]}" = "/tmp/wall.png 0.15 float" ]
  [ "${lines[1]}" = "/tmp/wall.png 0.15 float" ]
  python3 "$GEN" --root "$REPO_ROOT" --out "$OUT" --background ""
  run python3 - "$OUT" <<'PY'
import json,sys
for p in json.load(open(sys.argv[1]))['Profiles']:
    print('Background Image Location' in p, 'Blend' in p)
PY
  [ "${lines[0]}" = "False False" ]
  [ "${lines[1]}" = "False False" ]
}

# --- the adapter contract ----------------------------------------------------

@test "name, capabilities and font" {
  load_adapter
  [ "$(terminal_name)" = "iterm2" ]
  [ "$(terminal_capabilities)" = "truecolor images background panel hotkey" ]
  [ "$(terminal_font_name)" = "JetBrainsMono NF" ]
}

@test "terminal_detect is true only under TERM_PROGRAM=iTerm.app" {
  load_adapter
  status=0; ( TERM_PROGRAM=iTerm.app terminal_detect ) || status=$?
  [ "$status" -eq 0 ]
  status=0; ( TERM_PROGRAM=Apple_Terminal terminal_detect ) || status=$?
  [ "$status" -eq 1 ]
  status=0; ( unset TERM_PROGRAM; terminal_detect ) || status=$?
  [ "$status" -eq 1 ]
  status=0; ( TERM=xterm-kitty terminal_detect ) || status=$?
  [ "$status" -eq 1 ]
}

@test "terminal_installed follows the app bundle in either Applications dir" {
  load_adapter
  # $HOME is the throwaway one, so this never sees the developer's own iTerm2
  # unless it really is installed in /Applications.
  if [ -e /Applications/iTerm.app ]; then skip "iTerm2 is installed in /Applications on this Mac"; fi
  status=0; terminal_installed || status=$?
  [ "$status" -eq 1 ]
  mkdir -p "$HOME/Applications/iTerm.app"
  status=0; terminal_installed || status=$?
  [ "$status" -eq 0 ]
}

@test "iterm_write_profiles writes into the DynamicProfiles dir" {
  load_adapter
  status=0; output="$(iterm_write_profiles 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ -f "$PROF" ]
}

@test "iterm_apply_prefs in dry-run prints the defaults commands without running them" {
  load_adapter
  export NEKOSHELL_DRY_RUN=1
  status=0; output="$(iterm_apply_prefs 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "defaults write com.googlecode.iterm2 Default Bookmark Guid -string 4E4B4F53-4845-4C4C-0001-000000000001"
  assert_contains "$output" "HideTab -bool true"
  assert_contains "$output" "TerminalMargin -int 16"
  assert_contains "$output" "DimInactiveSplitPanes -bool true"
}

# --- terminal_apply ----------------------------------------------------------

@test "terminal_apply writes the profiles, downloads the shell integration and applies the prefs" {
  load_adapter
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ -f "$PROF" ]
  [ -f "$HOME/.iterm2_shell_integration.zsh" ]
  assert_contains "$output" "Default Bookmark Guid"
  assert_contains "$output" "iterm2.com/shell_integration/zsh"
}

@test "terminal_apply leaves an existing shell integration file alone" {
  load_adapter
  printf 'mine\n' > "$HOME/.iterm2_shell_integration.zsh"
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "shell_integration/zsh"
  [ "$(cat "$HOME/.iterm2_shell_integration.zsh")" = "mine" ]
}

@test "terminal_apply only warns about the prefs while iTerm2 is running, and still succeeds" {
  load_adapter
  export FAKE_ITERM_RUNNING=1
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ -f "$PROF" ]
  assert_contains "$output" "iTerm2 is running"
  assert_contains "$output" "nekoshell terminal apply"
  assert_not_contains "$output" "Default Bookmark Guid"
}

@test "terminal_apply re-applies a stored background" {
  load_adapter
  config_set background "$HOME/wall.png"
  config_set background_opacity 0.8
  status=0; output="$(terminal_apply latte 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(profile_backgrounds)" = "$HOME/wall.png 0.2 | $HOME/wall.png 0.2" ]
}

# --- terminal_background -----------------------------------------------------

@test "terminal_background sets the image and blend on both profiles" {
  load_adapter
  status=0; output="$(terminal_background "$HOME/wall.png" 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(profile_backgrounds)" = "$HOME/wall.png 0.15 | $HOME/wall.png 0.15" ]
}

@test "terminal_background honours an explicit opacity" {
  load_adapter
  status=0; output="$(terminal_background "$HOME/wall.png" 0.5 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(profile_backgrounds)" = "$HOME/wall.png 0.5 | $HOME/wall.png 0.5" ]
}

@test "terminal_background none clears the image and blend" {
  load_adapter
  terminal_background "$HOME/wall.png" >/dev/null 2>&1
  status=0; output="$(terminal_background none 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(profile_backgrounds)" = "none False | none False" ]
}

@test "terminal_background prints the live escape only inside iTerm2" {
  load_adapter
  b64="$(printf %s "$HOME/wall.png" | base64)"
  status=0; output="$(terminal_background "$HOME/wall.png" 2>&1)" || status=$?
  assert_not_contains "$output" "SetBackgroundImageFile"
  export TERM_PROGRAM=iTerm.app
  status=0; output="$(terminal_background "$HOME/wall.png" 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "]1337;SetBackgroundImageFile=$b64"
  assert_contains "$output" "confirm"
  status=0; output="$(terminal_background none 2>&1)" || status=$?
  assert_contains "$output" "]1337;SetBackgroundImageFile="
  assert_not_contains "$output" "$b64"
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

# --- the doctor and the commands --------------------------------------------

@test "doctor fails the profiles row before anything is applied" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  run "$NK" doctor
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +iterm2 profiles'
  assert_matches "$output" 'warn +iterm2 prefs +pending'
  assert_matches "$output" 'warn +iterm2 shell integration'
}

@test "doctor reports the profiles, prefs, shell integration and font rows after an apply" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  "$NK" terminal apply >/dev/null 2>&1
  run "$NK" doctor
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +iterm2 profiles'
  assert_matches "$output" 'warn +iterm2 prefs +pending: quit iTerm2, run: nekoshell terminal apply'
  assert_matches "$output" 'ok +iterm2 shell integration'
  assert_matches "$output" 'ok +iterm2 font +JetBrainsMonoNF'
}

@test "doctor fails the profiles row when the file is not JSON" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  mkdir -p "$(dirname "$PROF")"
  printf 'not json\n' > "$PROF"
  run "$NK" doctor
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +iterm2 profiles'
}

@test "nekoshell terminal use iterm2 records the terminal and writes the profiles" {
  printf 'root = "%s"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  run "$NK" terminal use iterm2
  [ "$status" -eq 0 ]
  [ -f "$PROF" ]
  grep -q '^terminal = "iterm2"$' "$HOME/.config/nekoshell/nekoshell.toml"
  run "$NK" terminal capabilities
  assert_contains "$output" "hotkey"
}

@test "nekoshell theme latte re-renders the profiles in latte" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  run "$NK" theme latte
  [ "$status" -eq 0 ]
  run python3 - "$PROF" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))['Profiles'][0]
bg=p['Background Color']
print(round(bg['Red Component']*255), round(bg['Green Component']*255), round(bg['Blue Component']*255))
PY
  [ "${lines[0]}" = "239 241 245" ]
}
