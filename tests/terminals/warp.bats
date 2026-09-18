#!/usr/bin/env bats
# The Warp terminal adapter: the settings.toml key editor, the theme and tab
# config files, the adapter contract on top of them, and the rows it reports
# to the doctor.
load ../helpers

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_ROOT="$REPO_ROOT"
  # The real adapters directory, not the fixtures one: warp is the adapter
  # under test. Unset rather than pointed at terminals/, so core/lib/terminal.sh
  # derives it the way a real run does.
  unset NEKOSHELL_TERMINALS_DIR
  unset NEKOSHELL_PANEL TMUX TERM_PROGRAM NEKOSHELL_DRY_RUN
  export TERM=xterm-256color
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "warp"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" >"$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  SETTINGS_PY="$REPO_ROOT/terminals/warp/settings.py"
  SETTINGS="$HOME/.warp/settings.toml"
  THEME_MOCHA="$HOME/.warp/themes/nekoshell_mocha.yaml"
  THEME_LATTE="$HOME/.warp/themes/nekoshell_latte.yaml"
  TAB="$HOME/.warp/tab_configs/nekoshell_music.toml"
  PREVIOUS="$HOME/.config/nekoshell/warp-previous.toml"
}
teardown() { teardown_tmp_home; }

# Sourcing the libraries pulls in log.sh's run(), which shadows bats' own run()
# for the rest of the test process; these tests capture with $( ) instead, the
# way tests/core/terminal.bats does.
load_adapter() {
  local l
  for l in log paths config backup theme terminal; do
    # shellcheck source=/dev/null
    source "$REPO_ROOT/core/lib/$l.sh"
  done
  terminal_load warp
}

# A settings.toml with a theme, a font and a section of the user's own, the
# shape Warp's Settings panel writes.
write_user_settings() {
  mkdir -p "$HOME/.warp"
  printf '# mine\n[appearance.themes]\nsystem_theme = false\ntheme = "dark"\n\n[appearance.text]\nfont_name = "Hack"\n\n[terminal]\nfoo = 1\n' >"$SETTINGS"
}

# The value of one dotted key in FILE, as settings.py reads it back.
setting() { python3 "$SETTINGS_PY" "$1" get "$2"; }

# python3 on the real PATH with a TOML parser (3.11+), or nothing.
toml_python() {
  local py
  for py in /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
    if [[ -x "$py" ]] && "$py" -c 'import tomllib' 2>/dev/null; then
      printf '%s' "$py"
      return 0
    fi
  done
  return 1
}

# --- settings.py -------------------------------------------------------------

@test "settings.py creates the file with a section per parent" {
  run python3 "$SETTINGS_PY" "$SETTINGS" set appearance.themes.theme '"dark"' nekoshell
  [ "$status" -eq 0 ]
  run python3 "$SETTINGS_PY" "$SETTINGS" set appearance.text.font_size 15.0 nekoshell
  [ "$status" -eq 0 ]
  run cat "$SETTINGS"
  [ "${lines[0]}" = "[appearance.themes]" ]
  [ "${lines[1]}" = 'theme = "dark"  # nekoshell' ]
  [ "${lines[2]}" = "[appearance.text]" ]
  [ "${lines[3]}" = "font_size = 15.0  # nekoshell" ]
}

@test "settings.py replaces a key inside an existing section and keeps every other line" {
  write_user_settings
  run python3 "$SETTINGS_PY" "$SETTINGS" set appearance.themes.theme '"light"' nekoshell
  [ "$status" -eq 0 ]
  run cat "$SETTINGS"
  [ "${lines[0]}" = "# mine" ]
  [ "${lines[1]}" = "[appearance.themes]" ]
  [ "${lines[2]}" = 'theme = "light"  # nekoshell' ]
  [ "${lines[3]}" = "system_theme = false" ]
  assert_contains "$output" 'font_name = "Hack"'
  assert_contains "$output" "foo = 1"
  [ "$(grep -c '^theme' "$SETTINGS")" = "1" ]
  [ "$(setting "$SETTINGS" appearance.themes.theme)" = '"light"' ]
}

@test "settings.py removes a sub-table form of the key before writing, so it is never defined twice" {
  mkdir -p "$HOME/.warp"
  printf '[appearance.themes]\nsystem_theme = true\n[appearance.themes.theme.custom]\nname = "old"\npath = "/old"\n[terminal]\nx = 1\n' >"$SETTINGS"
  python3 "$SETTINGS_PY" "$SETTINGS" set appearance.themes.theme '"dark"' nekoshell
  run cat "$SETTINGS"
  assert_not_contains "$output" "appearance.themes.theme.custom"
  assert_not_contains "$output" '"old"'
  assert_contains "$output" 'theme = "dark"  # nekoshell'
  assert_contains "$output" "system_theme = true"
  assert_contains "$output" "x = 1"
}

@test "settings.py writes a dotted key under a parent header when that is where the table lives" {
  mkdir -p "$HOME/.warp"
  printf '[appearance]\nthemes.theme = "dark"\ntext.font_size = 12.0\n' >"$SETTINGS"
  python3 "$SETTINGS_PY" "$SETTINGS" set appearance.themes.theme '"light"' nekoshell
  run cat "$SETTINGS"
  # A [appearance.themes] header after `themes.theme` under [appearance] would
  # be a TOML error, which Warp answers by ignoring the whole file.
  assert_not_contains "$output" "[appearance.themes]"
  assert_contains "$output" 'themes.theme = "light"  # nekoshell'
  assert_contains "$output" "text.font_size = 12.0"
  [ "$(grep -c 'themes.theme' "$SETTINGS")" = "1" ]
}

@test "settings.py get strips only the nekoshell tag, and unset leaves nothing behind" {
  mkdir -p "$HOME/.warp"
  printf '[appearance.text]\nfont_name = "Hack" # theirs\nfont_size = 15.0  # nekoshell\n' >"$SETTINGS"
  [ "$(setting "$SETTINGS" appearance.text.font_name)" = '"Hack" # theirs' ]
  [ "$(setting "$SETTINGS" appearance.text.font_size)" = "15.0" ]
  python3 "$SETTINGS_PY" "$SETTINGS" unset appearance.text.font_size
  status=0; setting "$SETTINGS" appearance.text.font_size || status=$?
  [ "$status" -eq 1 ]
  run cat "$SETTINGS"
  [ "$output" = $'[appearance.text]\nfont_name = "Hack" # theirs' ]
}

@test "every settings.py result parses as TOML" {
  local py
  py="$(toml_python)" || true
  [[ -n "$py" ]] || skip "no python3 with tomllib on this Mac"
  write_user_settings
  python3 "$SETTINGS_PY" "$SETTINGS" set appearance.themes.theme '{ custom = { name = "nekoshell mocha", path = "/x/nekoshell_mocha.yaml" } }' nekoshell
  python3 "$SETTINGS_PY" "$SETTINGS" set appearance.text.font_name '"JetBrainsMono Nerd Font"' nekoshell
  python3 "$SETTINGS_PY" "$SETTINGS" set appearance.text.font_size 15.0 nekoshell
  run "$py" - "$SETTINGS" <<'PY'
import sys, tomllib
d = tomllib.load(open(sys.argv[1], "rb"))
print(d["appearance"]["themes"]["theme"]["custom"]["path"], d["appearance"]["themes"]["system_theme"])
print(d["appearance"]["text"]["font_name"], d["appearance"]["text"]["font_size"], d["terminal"]["foo"])
PY
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "/x/nekoshell_mocha.yaml False" ]
  [ "${lines[1]}" = "JetBrainsMono Nerd Font 15.0 1" ]
}

# --- the adapter contract ----------------------------------------------------

@test "name, capabilities and font" {
  load_adapter
  [ "$(terminal_name)" = "warp" ]
  [ "$(terminal_capabilities)" = "truecolor images background panel" ]
  [ "$(terminal_font_name)" = "JetBrainsMono Nerd Font" ]
}

@test "terminal_detect is true only under TERM_PROGRAM=WarpTerminal" {
  load_adapter
  status=0; ( TERM_PROGRAM=WarpTerminal terminal_detect ) || status=$?
  [ "$status" -eq 0 ]
  status=0; ( TERM_PROGRAM=iTerm.app terminal_detect ) || status=$?
  [ "$status" -eq 1 ]
  status=0; ( unset TERM_PROGRAM; terminal_detect ) || status=$?
  [ "$status" -eq 1 ]
}

@test "terminal_installed follows the app bundle in either Applications dir" {
  load_adapter
  if [ -e /Applications/Warp.app ]; then skip "Warp is installed in /Applications on this Mac"; fi
  status=0; terminal_installed || status=$?
  [ "$status" -eq 1 ]
  mkdir -p "$HOME/Applications/Warp.app"
  status=0; terminal_installed || status=$?
  [ "$status" -eq 0 ]
}

# --- terminal_apply ----------------------------------------------------------

@test "terminal_apply renders the theme file from the palette and marks it" {
  load_adapter
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ -f "$THEME_MOCHA" ]
  output="$(cat "$THEME_MOCHA")"
  assert_contains "$(head -n 1 "$THEME_MOCHA")" "nekoshell"
  assert_contains "$output" "name: nekoshell mocha"
  # base, text, rosewater and mauve for mocha, from core/theme/palettes.json.
  assert_contains "$output" "background: '#1e1e2e'"
  assert_contains "$output" "foreground: '#cdd6f4'"
  assert_contains "$output" "cursor: '#f5e0dc'"
  assert_contains "$output" "accent: '#cba6f7'"
  # ANSI 0 to 15 are the flavour's ansi roles: 0 black, 5 magenta, 8 bright black, 15 bright white.
  assert_matches "$output" "normal:.*black: '#45475a'"
  assert_matches "$output" "normal:.*magenta: '#f5c2e7'"
  assert_matches "$output" "bright:.*black: '#585b70'"
  assert_matches "$output" "bright:.*white: '#bac2de'"
  assert_contains "$output" "details: darker"
  assert_not_contains "$output" "background_image"
  assert_not_contains "$output" "@@"
}

@test "terminal_apply latte is a lighter theme and replaces the mocha file" {
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  status=0; output="$(terminal_apply latte 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ -f "$THEME_LATTE" ]
  [ ! -f "$THEME_MOCHA" ]
  output="$(cat "$THEME_LATTE")"
  assert_contains "$output" "background: '#eff1f5'"
  assert_contains "$output" "details: lighter"
  assert_contains "$(setting "$SETTINGS" appearance.themes.theme)" "$THEME_LATTE"
}

@test "terminal_apply selects the theme and font in settings.toml and writes the tab config" {
  load_adapter
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(setting "$SETTINGS" appearance.themes.theme)" = "{ custom = { name = \"nekoshell mocha\", path = \"$THEME_MOCHA\" } }" ]
  [ "$(setting "$SETTINGS" appearance.text.font_name)" = '"JetBrainsMono Nerd Font"' ]
  [ "$(setting "$SETTINGS" appearance.text.font_size)" = "15.0" ]
  [ -f "$TAB" ]
  output="$(cat "$TAB")"
  assert_contains "$(head -n 1 "$TAB")" "nekoshell"
  assert_contains "$output" 'name = "nekoshell music"'
  assert_contains "$output" 'type = "terminal"'
  assert_contains "$output" "commands = [\"NEKOSHELL_PANEL=1 '$REPO_ROOT/bin/nekoshell' music --here\"]"
  assert_contains "$output" "is_focused = true"
  assert_not_contains "$output" "defaults"
}

@test "terminal_apply keeps the user's settings, backs the file up once and remembers the old values" {
  load_adapter
  write_user_settings
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "backing up your .warp/settings.toml"
  output="$(cat "$SETTINGS")"
  [ "$(head -n 1 "$SETTINGS")" = "# mine" ]
  assert_contains "$output" "system_theme = false"
  assert_contains "$output" "foo = 1"
  [ "$(grep -c '^theme' "$SETTINGS")" = "1" ]
  [ "$(grep -c '^font_name' "$SETTINGS")" = "1" ]
  output="$(cat "$PREVIOUS")"
  [ "$output" = $'theme = "dark"\nfont_name = "Hack"' ]
  # One backup set holds the original, and it is listed for uninstall.
  [ "$(cat "$HOME"/.local/share/nekoshell/backup/*/manifest.txt)" = ".warp/settings.toml" ]
  [ "$(cat "$HOME"/.local/share/nekoshell/backup/*/.warp/settings.toml | grep -c 'theme = "dark"')" = "1" ]
  # A second apply neither backs up again nor rewrites the previous values.
  status=0; output="$(terminal_apply latte 2>&1)" || status=$?
  assert_not_contains "$output" "backing up"
  [ "$(cat "$PREVIOUS")" = $'theme = "dark"\nfont_name = "Hack"' ]
  [ "$(ls -d "$HOME"/.local/share/nekoshell/backup/*/ | wc -l | tr -d ' ')" = "1" ]
}

@test "terminal_apply twice yields the same files" {
  load_adapter
  write_user_settings
  terminal_apply mocha >/dev/null 2>&1
  cp "$SETTINGS" "$HOME/settings.1"
  cp "$THEME_MOCHA" "$HOME/theme.1"
  cp "$TAB" "$HOME/tab.1"
  terminal_apply mocha >/dev/null 2>&1
  cmp "$SETTINGS" "$HOME/settings.1"
  cmp "$THEME_MOCHA" "$HOME/theme.1"
  cmp "$TAB" "$HOME/tab.1"
  [ "$(ls "$HOME/.warp/themes" | wc -l | tr -d ' ')" = "1" ]
}

@test "a dry run reports every write and changes nothing" {
  load_adapter
  write_user_settings
  cp "$SETTINGS" "$HOME/settings.before"
  export NEKOSHELL_DRY_RUN=1
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "theme_render_template"
  assert_contains "$output" "would append details: darker"
  assert_contains "$output" "would write $TAB"
  assert_contains "$output" "would record the current Warp theme"
  assert_contains "$output" "settings.py $SETTINGS set appearance.themes.theme"
  assert_contains "$output" "set appearance.text.font_name"
  [ ! -f "$THEME_MOCHA" ]
  [ ! -f "$TAB" ]
  [ ! -f "$PREVIOUS" ]
  cmp "$SETTINGS" "$HOME/settings.before"
  [ ! -d "$HOME/.local/share/nekoshell/backup" ]
  status=0; output="$(terminal_background "$HOME/w.jpg" 2>&1)" || status=$?
  [ ! -f "$HOME/.warp/themes/nekoshell_background.jpg" ]
}

@test "terminal_apply re-attaches a stored jpg background and skips any other kind" {
  load_adapter
  printf 'jpg\n' >"$HOME/wall.jpg"
  config_set background "$HOME/wall.jpg"
  config_set background_opacity 0.4
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ -f "$HOME/.warp/themes/nekoshell_background.jpg" ]
  output="$(cat "$THEME_MOCHA")"
  assert_matches "$output" "background_image:.*path: nekoshell_background.jpg.*opacity: 40"
  config_set background "$HOME/wall.png"
  rm -f "$HOME/.warp/themes/nekoshell_background.jpg"
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "only draws .jpg"
  output="$(cat "$THEME_MOCHA")"
  assert_not_contains "$output" "background_image"
}

# --- terminal_background -----------------------------------------------------

@test "terminal_background copies the jpg into the themes dir and writes the block" {
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  printf 'jpg\n' >"$HOME/wall.jpg"
  status=0; output="$(terminal_background "$HOME/wall.jpg" 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  cmp "$HOME/wall.jpg" "$HOME/.warp/themes/nekoshell_background.jpg"
  output="$(cat "$THEME_MOCHA")"
  assert_matches "$output" "background_image:.*path: nekoshell_background.jpg.*opacity: 85"
  # The image is a trailer on the same file: the colours are still there.
  assert_contains "$output" "background: '#1e1e2e'"
  status=0; output="$(terminal_background "$HOME/wall.jpg" 0.5 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  output="$(cat "$THEME_MOCHA")"
  assert_contains "$output" "opacity: 50"
  # Survives the next theme switch, without a nekoshell.toml entry.
  terminal_apply latte >/dev/null 2>&1
  output="$(cat "$THEME_LATTE")"
  assert_contains "$output" "opacity: 85"
  assert_contains "$output" "path: nekoshell_background.jpg"
}

@test "terminal_background makes a relative path absolute" {
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  printf 'jpg\n' >"$HOME/wall.jpg"
  cd "$HOME"
  status=0; output="$(terminal_background wall.jpg 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "cp $HOME/wall.jpg"
  [ -f "$HOME/.warp/themes/nekoshell_background.jpg" ]
}

@test "terminal_background refuses a non-jpg, a missing file and a bad opacity" {
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  printf 'png\n' >"$HOME/wall.png"
  status=0; output="$(terminal_background "$HOME/wall.png" 2>&1)" || status=$?
  [ "$status" -eq 1 ]
  assert_contains "$output" "only draws .jpg"
  assert_contains "$output" "sips"
  status=0; output="$(terminal_background "$HOME/nope.jpg" 2>&1)" || status=$?
  [ "$status" -eq 1 ]
  assert_contains "$output" "does not exist"
  printf 'jpg\n' >"$HOME/wall.jpg"
  status=0; output="$(terminal_background "$HOME/wall.jpg" 1.5 2>&1)" || status=$?
  [ "$status" -eq 1 ]
  assert_contains "$output" "opacity must be between 0 and 1"
  status=0; output="$(terminal_background "$HOME/wall.jpg" abc 2>&1)" || status=$?
  [ "$status" -eq 1 ]
  # Refused before anything was written.
  [ ! -f "$HOME/.warp/themes/nekoshell_background.jpg" ]
  output="$(cat "$THEME_MOCHA")"
  assert_not_contains "$output" "background_image"
  status=0; output="$(terminal_background 2>&1)" || status=$?
  [ "$status" -eq 1 ]
  assert_contains "$output" "usage"
}

@test "terminal_background none removes the copy and the block" {
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  printf 'jpg\n' >"$HOME/wall.jpg"
  terminal_background "$HOME/wall.jpg" >/dev/null 2>&1
  status=0; output="$(terminal_background none 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ ! -f "$HOME/.warp/themes/nekoshell_background.jpg" ]
  output="$(cat "$THEME_MOCHA")"
  assert_not_contains "$output" "background_image"
  assert_contains "$output" "details: darker"
}

# --- terminal_panel ----------------------------------------------------------

@test "terminal_panel opens the tab config in a new window inside Warp, pops up inside tmux, runs inline elsewhere" {
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  status=0; output="$(TERM_PROGRAM=WarpTerminal terminal_panel echo hi 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "open warp://tab_config/nekoshell_music?new_window=true"
  assert_not_contains "$output" $'\nhi'
  status=0; output="$(TERM_PROGRAM=WarpTerminal TMUX=1 terminal_panel echo hi 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "tmux display-popup"
  assert_not_contains "$output" "warp://"
  status=0; output="$(terminal_panel echo hi 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$output" = "hi" ]
}

@test "terminal_panel runs the command here when the tab config is missing" {
  load_adapter
  status=0; output="$(TERM_PROGRAM=WarpTerminal terminal_panel echo hi 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "nekoshell terminal apply"
  assert_contains "$output" "hi"
  assert_not_contains "$output" "warp://"
}

# --- terminal_remove ---------------------------------------------------------

@test "terminal_remove deletes the owned files and puts the old theme and font back" {
  load_adapter
  write_user_settings
  terminal_apply mocha >/dev/null 2>&1
  printf 'jpg\n' >"$HOME/wall.jpg"
  terminal_background "$HOME/wall.jpg" >/dev/null 2>&1
  status=0; output="$(terminal_remove 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ ! -f "$THEME_MOCHA" ]
  [ ! -f "$TAB" ]
  [ ! -f "$HOME/.warp/themes/nekoshell_background.jpg" ]
  [ ! -f "$PREVIOUS" ]
  [ "$(setting "$SETTINGS" appearance.themes.theme)" = '"dark"' ]
  [ "$(setting "$SETTINGS" appearance.text.font_name)" = '"Hack"' ]
  status=0; setting "$SETTINGS" appearance.text.font_size || status=$?
  [ "$status" -eq 1 ]
  output="$(cat "$SETTINGS")"
  assert_not_contains "$output" "nekoshell"
  assert_contains "$output" "system_theme = false"
  assert_contains "$output" "foo = 1"
}

@test "terminal_remove unsets keys that had no previous value" {
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  status=0; output="$(terminal_remove 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  output="$(cat "$SETTINGS")"
  assert_not_contains "$output" "theme ="
  assert_not_contains "$output" "font_name"
  assert_not_contains "$output" "font_size"
}

@test "terminal_remove leaves a theme or font the user changed since" {
  load_adapter
  write_user_settings
  terminal_apply mocha >/dev/null 2>&1
  python3 "$SETTINGS_PY" "$SETTINGS" set appearance.themes.theme '"dracula"'
  python3 "$SETTINGS_PY" "$SETTINGS" set appearance.text.font_name '"Menlo"'
  status=0; output="$(terminal_remove 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$(setting "$SETTINGS" appearance.themes.theme)" = '"dracula"' ]
  [ "$(setting "$SETTINGS" appearance.text.font_name)" = '"Menlo"' ]
  # The size was still ours and had no previous value, so it goes.
  status=0; setting "$SETTINGS" appearance.text.font_size || status=$?
  [ "$status" -eq 1 ]
}

@test "terminal_remove before any apply touches nothing" {
  load_adapter
  write_user_settings
  cp "$SETTINGS" "$HOME/settings.before"
  status=0; output="$(terminal_remove 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  cmp "$SETTINGS" "$HOME/settings.before"
}

# --- the files, checked by a parser ------------------------------------------

@test "the rendered theme is valid YAML with Warp's fields" {
  local rb
  rb="$(PATH=/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin command -v ruby 2>/dev/null || true)"
  [[ -n "$rb" ]] || skip "no ruby (for its YAML parser) on this Mac"
  load_adapter
  # terminal_background renders the flavour nekoshell.toml records.
  config_set theme_resolved latte
  terminal_apply latte >/dev/null 2>&1
  printf 'jpg\n' >"$HOME/wall.jpg"
  terminal_background "$HOME/wall.jpg" 0.3 >/dev/null 2>&1
  status=0
  output="$(
    "$rb" -ryaml -e '
y = YAML.load_file(ARGV[0])
puts [y["name"], y["accent"], y["background"], y["foreground"], y["cursor"], y["details"]].join(" ")
puts %w[normal bright].map { |k| y["terminal_colors"][k].keys.sort.join(",") }.join(" | ")
puts [y["background_image"]["path"], y["background_image"]["opacity"]].join(" ")
' "$THEME_LATTE" 2>&1
  )" || status=$?
  [ "$status" -eq 0 ]
  [ "$output" = $'nekoshell latte #8839ef #eff1f5 #4c4f69 #dc8a78 lighter\nblack,blue,cyan,green,magenta,red,white,yellow | black,blue,cyan,green,magenta,red,white,yellow\nnekoshell_background.jpg 30' ]
}

@test "the tab config and the edited settings.toml are valid TOML" {
  local py
  py="$(toml_python)" || true
  [[ -n "$py" ]] || skip "no python3 with tomllib on this Mac"
  load_adapter
  write_user_settings
  terminal_apply mocha >/dev/null 2>&1
  status=0
  output="$(
    "$py" - "$TAB" "$SETTINGS" "$THEME_MOCHA" 2>&1 <<'PY'
import sys, tomllib
tab = tomllib.load(open(sys.argv[1], "rb"))
print(tab["name"], tab["color"], len(tab["panes"]), tab["panes"][0]["id"], tab["panes"][0]["type"], tab["panes"][0]["is_focused"])
print(tab["panes"][0]["commands"][0])
s = tomllib.load(open(sys.argv[2], "rb"))
t = s["appearance"]["themes"]["theme"]["custom"]
print(t["name"], t["path"] == sys.argv[3], s["appearance"]["text"]["font_name"], s["appearance"]["text"]["font_size"], s["terminal"]["foo"])
PY
  )" || status=$?
  [ "$status" -eq 0 ]
  [ "$output" = "nekoshell music magenta 1 music terminal True
NEKOSHELL_PANEL=1 '$REPO_ROOT/bin/nekoshell' music --here
nekoshell mocha True JetBrainsMono Nerd Font 15.0 1" ]
}

# --- the doctor and the commands --------------------------------------------

@test "doctor fails every warp row before anything is applied" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  run "$NK" doctor
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +warp theme +missing for mocha'
  assert_matches "$output" 'fail +warp settings +no theme selected'
  assert_matches "$output" 'fail +warp font +no font_name'
  assert_matches "$output" 'fail +warp panel +missing'
}

@test "doctor passes every warp row after an apply" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  "$NK" terminal apply >/dev/null 2>&1
  run "$NK" doctor
  [ "$status" -eq 0 ]
  assert_matches "$output" "ok +warp theme +$THEME_MOCHA"
  assert_matches "$output" 'ok +warp settings +theme is nekoshell mocha'
  assert_matches "$output" 'ok +warp font +JetBrainsMono Nerd Font 15.0'
  assert_matches "$output" "ok +warp panel +$TAB"
}

@test "doctor fails the settings and font rows when the user picked something else" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  "$NK" terminal apply >/dev/null 2>&1
  python3 "$SETTINGS_PY" "$SETTINGS" set appearance.themes.theme '"dracula"'
  python3 "$SETTINGS_PY" "$SETTINGS" set appearance.text.font_name '"Menlo"'
  run "$NK" doctor
  [ "$status" -eq 1 ]
  assert_matches "$output" 'ok +warp theme'
  assert_matches "$output" 'fail +warp settings +theme is not nekoshell mocha'
  assert_matches "$output" 'fail +warp font +"Menlo" is not JetBrainsMono Nerd Font'
  assert_matches "$output" 'ok +warp panel'
}

@test "nekoshell terminal use warp records the terminal and writes the files" {
  printf 'root = "%s"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" >"$HOME/.config/nekoshell/nekoshell.toml"
  run "$NK" terminal use warp
  [ "$status" -eq 0 ]
  [ -f "$THEME_MOCHA" ]
  [ -f "$TAB" ]
  [ -f "$SETTINGS" ]
  grep -q '^terminal = "warp"$' "$HOME/.config/nekoshell/nekoshell.toml"
  run "$NK" terminal capabilities
  assert_contains "$output" "panel"
  assert_not_contains "$output" "hotkey"
}

@test "nekoshell theme latte re-renders the theme in latte" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  run "$NK" theme latte
  [ "$status" -eq 0 ]
  [ -f "$THEME_LATTE" ]
  output="$(cat "$THEME_LATTE")"
  assert_contains "$output" "background: '#eff1f5'"
  assert_contains "$(setting "$SETTINGS" appearance.themes.theme)" "$THEME_LATTE"
}

@test "uninstall removes the warp files and restores the settings" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  write_user_settings
  "$NK" terminal apply >/dev/null 2>&1
  [ -f "$THEME_MOCHA" ]
  run "$NK" uninstall --yes
  [ "$status" -eq 0 ]
  [ ! -f "$THEME_MOCHA" ]
  [ ! -f "$TAB" ]
  [ ! -f "$PREVIOUS" ]
  # The backup restore put the original file back, so the user's own lines
  # are there and none of ours.
  output="$(cat "$SETTINGS")"
  assert_contains "$output" 'theme = "dark"'
  assert_contains "$output" 'font_name = "Hack"'
  assert_not_contains "$output" "nekoshell"
}

@test "latte renders a dark ANSI black, so black text stays readable on the light base" {
  load_adapter
  terminal_apply latte >/dev/null 2>&1
  output="$(cat "$HOME/.warp/themes/nekoshell_latte.yaml")"
  assert_contains "$output" "background: '#eff1f5'"
  assert_matches "$output" "normal:.*black: '#5c5f77'"
  assert_matches "$output" "bright:.*black: '#6c6f85'"
  assert_matches "$output" "normal:.*white: '#acb0be'"
}
