#!/usr/bin/env bats
# The Apple Terminal.app adapter: the .terminal profile generator, the adapter
# contract on top of it (profiles live inside com.apple.Terminal, so the fake
# `defaults` keeps a real plist store for that domain), and the rows it
# reports to the doctor.
load ../helpers

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_ROOT="$REPO_ROOT"
  unset NEKOSHELL_TERMINALS_DIR
  unset NEKOSHELL_PANEL TMUX TERM_PROGRAM FAKE_ITERM_RUNNING FAKE_SW_VERS_PRODUCT_VERSION TERMINAL_APP_BUNDLE
  export TERM=xterm-256color
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "terminal-app"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  GEN="$REPO_ROOT/terminals/terminal-app/build-profile.py"
  OUT="$HOME/nekoshell.terminal"
  DIR="$HOME/.local/share/nekoshell/terminal-app"
  PROF="$DIR/nekoshell.terminal"
  CMD="$DIR/nekoshell-music.command"
  STORE="$HOME/.fake-defaults/com.apple.Terminal.plist"
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
  terminal_load terminal-app
}

# seed_prefs [FONT]: what a Mac with a profile of the user's own looks like
# before nekoshell touches it: "Clear Dark" carrying an archived font, and
# both default keys naming it. FONT is that profile's font name.
seed_prefs() {
  mkdir -p "$(dirname "$STORE")"
  python3 - "$STORE" "${1:-SFMonoTerminal-Regular}" <<'PY'
import plistlib, sys
font = {"$version": 100000, "$archiver": "NSKeyedArchiver", "$top": {"root": plistlib.UID(1)},
        "$objects": ["$null", {"NSSize": 12.0, "NSfFlags": 16, "NSName": plistlib.UID(2), "$class": plistlib.UID(3)},
                     sys.argv[2], {"$classname": "NSFont", "$classes": ["NSFont", "NSObject"]}]}
prefs = {"Default Window Settings": "Clear Dark", "Startup Window Settings": "Clear Dark",
         "Window Settings": {"Clear Dark": {"name": "Clear Dark", "type": "Window Settings",
                                            "Font": plistlib.dumps(font, fmt=plistlib.FMT_BINARY)}}}
with open(sys.argv[1], "wb") as f:
    plistlib.dump(prefs, f)
PY
}

# prefs_summary: one line describing the fake store: the default profile, the
# profile names in Window Settings, and the nekoshell profile's font.
prefs_summary() {
  python3 - "$STORE" <<'PY'
import os, plistlib, sys
if not os.path.exists(sys.argv[1]):
    print("no prefs"); sys.exit(0)
prefs = plistlib.load(open(sys.argv[1], "rb"))
ws = prefs.get("Window Settings", {})
font = ""
if "nekoshell" in ws:
    f = plistlib.loads(ws["nekoshell"]["Font"])
    font = f["$objects"][2]
print(prefs.get("Default Window Settings", "-"), prefs.get("Startup Window Settings", "-"), ",".join(sorted(ws)), font)
PY
}

# rgb FILE KEY: the colour under KEY in a .terminal file as 0..255 values.
rgb() {
  python3 - "$1" "$2" <<'PY'
import plistlib, sys
p = plistlib.load(open(sys.argv[1], "rb"))
c = plistlib.loads(p[sys.argv[2]])["$objects"][1]
print(" ".join(str(round(float(x) * 255)) for x in c["NSRGB"].rstrip(b"\x00").split()))
PY
}

# --- the generator -----------------------------------------------------------

@test "generator writes one profile named nekoshell with the font and window keys" {
  run python3 "$GEN" --root "$REPO_ROOT" --out "$OUT"
  [ "$status" -eq 0 ]
  run python3 - "$OUT" <<'PY'
import plistlib, sys
p = plistlib.load(open(sys.argv[1], "rb"))
print(p["name"], p["type"], p["ProfileCurrentVersion"], p["FontAntialias"], p["columnCount"], p["rowCount"], p["useOptionAsMetaKey"], p["Bell"], p["shellExitAction"])
print(len([k for k in p if k.startswith("ANSI")]), type(p["Font"]).__name__, type(p["BackgroundColor"]).__name__)
PY
  [ "${lines[0]}" = "nekoshell Window Settings 2.09 True 120 36 True False 1" ]
  [ "${lines[1]}" = "16 bytes bytes" ]
}

@test "the generated .terminal passes plutil -lint" {
  PATH=/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin command -v plutil >/dev/null || skip "plutil not installed"
  python3 "$GEN" --root "$REPO_ROOT" --out "$OUT"
  run plutil -lint "$OUT"
  [ "$status" -eq 0 ]
  assert_contains "$output" "OK"
}

@test "Font and a colour decode to the NSKeyedArchiver shapes Terminal.app writes" {
  python3 "$GEN" --root "$REPO_ROOT" --out "$OUT"
  run python3 - "$OUT" <<'PY'
import plistlib, sys
p = plistlib.load(open(sys.argv[1], "rb"))
f = plistlib.loads(p["Font"])
print(f["$archiver"], f["$version"], f["$top"]["root"].data, f["$objects"][0])
o = f["$objects"][1]
print(o["NSSize"], o["NSfFlags"], o["NSName"].data, o["$class"].data, f["$objects"][2], f["$objects"][3]["$classname"], f["$objects"][3]["$classes"])
c = plistlib.loads(p["ANSIRedColor"])
o = c["$objects"][1]
print(c["$top"]["root"].data, o["NSColorSpace"], o["$class"].data, o["NSRGB"], c["$objects"][2]["$classname"], c["$objects"][2]["$classes"])
PY
  [ "${lines[0]}" = "NSKeyedArchiver 100000 1 \$null" ]
  [ "${lines[1]}" = "15.0 16 2 3 JetBrainsMonoNF-Regular NSFont ['NSFont', 'NSObject']" ]
  # mocha red f38ba8: three decimal components, space separated, NUL terminated.
  [ "${lines[2]}" = "1 2 2 b'0.952941 0.545098 0.658824\\x00' NSColor ['NSColor', 'NSObject']" ]
}

@test "colour roles follow the shared ANSI order and the text/background/cursor rule" {
  python3 "$GEN" --root "$REPO_ROOT" --out "$OUT"
  [ "$(rgb "$OUT" BackgroundColor)" = "30 30 46" ]      # base
  [ "$(rgb "$OUT" TextColor)" = "205 214 244" ]         # text
  [ "$(rgb "$OUT" TextBoldColor)" = "205 214 244" ]     # text
  [ "$(rgb "$OUT" CursorColor)" = "245 224 220" ]       # rosewater
  [ "$(rgb "$OUT" SelectionColor)" = "88 91 112" ]      # surface2
  [ "$(rgb "$OUT" ANSIBlackColor)" = "69 71 90" ]       # surface1
  [ "$(rgb "$OUT" ANSIMagentaColor)" = "245 194 231" ]  # pink
  [ "$(rgb "$OUT" ANSICyanColor)" = "148 226 213" ]     # teal
  [ "$(rgb "$OUT" ANSIWhiteColor)" = "186 194 222" ]    # subtext1
  [ "$(rgb "$OUT" ANSIBrightBlackColor)" = "88 91 112" ] # surface2
  [ "$(rgb "$OUT" ANSIBrightWhiteColor)" = "166 173 200" ] # subtext0
}

@test "--flavor picks another Catppuccin palette from core/theme/palettes.json" {
  python3 "$GEN" --root "$REPO_ROOT" --out "$OUT" --flavor latte
  [ "$(rgb "$OUT" BackgroundColor)" = "239 241 245" ]
  [ "$(rgb "$OUT" TextColor)" = "76 79 105" ]
}

@test "an unknown flavour is refused instead of written" {
  run python3 "$GEN" --root "$REPO_ROOT" --out "$OUT" --flavor dracula
  [ "$status" -ne 0 ]
  [ ! -f "$OUT" ]
}

@test "--font and --size land in the Font archive" {
  python3 "$GEN" --root "$REPO_ROOT" --out "$OUT" --font Menlo-Regular --size 13
  run python3 -c 'import plistlib,sys; f=plistlib.loads(plistlib.load(open(sys.argv[1],"rb"))["Font"]); print(f["$objects"][2], f["$objects"][1]["NSSize"])' "$OUT"
  [ "$output" = "Menlo-Regular 13.0" ]
}

# --- the adapter contract ----------------------------------------------------

@test "name, capabilities and font" {
  load_adapter
  [ "$(terminal_name)" = "terminal-app" ]
  [ "$(terminal_font_name)" = "JetBrainsMonoNF-Regular" ]
  # The fake sw_vers says 26.0 unless told otherwise.
  [ "$(terminal_capabilities)" = "truecolor panel" ]
  export FAKE_SW_VERS_PRODUCT_VERSION=15.6.1
  [ "$(terminal_capabilities)" = "panel" ]
  [ "$(terminal_app_macos_major)" = "15" ]
  export FAKE_SW_VERS_PRODUCT_VERSION=garbage
  [ "$(terminal_app_macos_major)" = "0" ]
}

@test "terminal_detect is true only under TERM_PROGRAM=Apple_Terminal" {
  load_adapter
  status=0; ( TERM_PROGRAM=Apple_Terminal terminal_detect ) || status=$?
  [ "$status" -eq 0 ]
  status=0; ( TERM_PROGRAM=iTerm.app terminal_detect ) || status=$?
  [ "$status" -eq 1 ]
  status=0; ( unset TERM_PROGRAM; terminal_detect ) || status=$?
  [ "$status" -eq 1 ]
}

@test "terminal_installed follows the Terminal.app bundle" {
  # The bundle is part of macOS, so the missing case needs the path overridden.
  export TERMINAL_APP_BUNDLE="$HOME/Terminal.app"
  load_adapter
  if [ -e /Applications/Utilities/Terminal.app ]; then skip "an older macOS still has Terminal.app under /Applications"; fi
  status=0; terminal_installed || status=$?
  [ "$status" -eq 1 ]
  mkdir -p "$HOME/Terminal.app"
  status=0; terminal_installed || status=$?
  [ "$status" -eq 0 ]
}

@test "terminal_background is not supported" {
  load_adapter
  status=0; output="$(terminal_background /x.png 2>&1)" || status=$?
  [ "$status" -eq 1 ]
  assert_contains "$output" "background is not supported by terminal-app"
}

# --- terminal_apply ----------------------------------------------------------

@test "terminal_apply renders the profile, installs it, makes it the default and writes the .command" {
  seed_prefs
  load_adapter
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ -f "$PROF" ]
  [ -x "$CMD" ]
  assert_contains "$output" "build-profile.py"
  assert_contains "$output" "--font JetBrainsMonoNF-Regular --size 15"
  assert_contains "$output" "defaults write com.apple.Terminal Window Settings -dict-add nekoshell"
  assert_contains "$output" "defaults write com.apple.Terminal Default Window Settings -string nekoshell"
  assert_contains "$output" "defaults write com.apple.Terminal Startup Window Settings -string nekoshell"
  [ "$(prefs_summary)" = "nekoshell nekoshell Clear Dark,nekoshell JetBrainsMonoNF-Regular" ]
  [ "$(rgb "$PROF" BackgroundColor)" = "30 30 46" ]
  grep -q '^terminal_app_previous_default = "Clear Dark"$' "$HOME/.config/nekoshell/nekoshell.toml"
  [ "$(head -n 1 "$CMD")" = "#!/bin/zsh -l" ]
  grep -q '^export NEKOSHELL_PANEL=1$' "$CMD"
  grep -q "^exec $REPO_ROOT/bin/nekoshell music --here$" "$CMD"
}

@test "terminal_apply records Basic as the previous default on a Mac that never set one" {
  load_adapter
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  grep -q '^terminal_app_previous_default = "Basic"$' "$HOME/.config/nekoshell/nekoshell.toml"
}

@test "terminal_apply twice yields the same files, one profile and the original previous default" {
  seed_prefs
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  cp "$PROF" "$HOME/first.terminal"
  cp "$CMD" "$HOME/first.command"
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  cmp -s "$PROF" "$HOME/first.terminal"
  cmp -s "$CMD" "$HOME/first.command"
  [ "$(prefs_summary)" = "nekoshell nekoshell Clear Dark,nekoshell JetBrainsMonoNF-Regular" ]
  # Not overwritten with "nekoshell": the value worth keeping is what came before.
  grep -q '^terminal_app_previous_default = "Clear Dark"$' "$HOME/.config/nekoshell/nekoshell.toml"
  [ "$(grep -c terminal_app_previous_default "$HOME/.config/nekoshell/nekoshell.toml")" = "1" ]
}

@test "a dry run reports every step and changes nothing" {
  seed_prefs
  load_adapter
  export NEKOSHELL_DRY_RUN=1
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "build-profile.py"
  assert_contains "$output" "would record terminal_app_previous_default = Clear Dark"
  assert_contains "$output" "Default Window Settings -string nekoshell"
  assert_contains "$output" "would write $CMD"
  [ ! -e "$DIR" ]
  [ "$(prefs_summary)" = "Clear Dark Clear Dark Clear Dark " ]
  assert_not_contains "$(cat "$HOME/.config/nekoshell/nekoshell.toml")" "terminal_app_previous_default"
}

@test "terminal_apply warns while Terminal.app is running and still succeeds" {
  load_adapter
  # The fake pgrep reports any process as running under this variable; its
  # name is iTerm2's only because that adapter needed it first.
  export FAKE_ITERM_RUNNING=1
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "Terminal.app is running and reads its profiles at launch: quit and reopen it"
  [ "$(prefs_summary)" = "nekoshell nekoshell nekoshell JetBrainsMonoNF-Regular" ]
}

@test "terminal_app_needs_restart is true only for a running Terminal that started before the profile was written" {
  seed_prefs
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  # Not running: nothing to restart.
  status=0; terminal_app_needs_restart || status=$?
  [ "$status" -eq 1 ]
  export FAKE_ITERM_RUNNING=1
  # Running with no recorded launch time: counted as old.
  status=0; terminal_app_needs_restart || status=$?
  [ "$status" -eq 0 ]
  # Launched a minute after the profile was written (the key is a UTC datetime).
  python3 - "$STORE" "$PROF" <<'PY'
import datetime, os, plistlib, sys
p = plistlib.load(open(sys.argv[1], "rb"))
p["LastTerminalStartTime"] = datetime.datetime.utcfromtimestamp(os.path.getmtime(sys.argv[2]) + 60)
plistlib.dump(p, open(sys.argv[1], "wb"))
PY
  status=0; terminal_app_needs_restart || status=$?
  [ "$status" -eq 1 ]
  # Launched an hour before it.
  python3 - "$STORE" "$PROF" <<'PY'
import datetime, os, plistlib, sys
p = plistlib.load(open(sys.argv[1], "rb"))
p["LastTerminalStartTime"] = datetime.datetime.utcfromtimestamp(os.path.getmtime(sys.argv[2]) - 3600)
plistlib.dump(p, open(sys.argv[1], "wb"))
PY
  status=0; terminal_app_needs_restart || status=$?
  [ "$status" -eq 0 ]
}

@test "terminal_apply warns about 256 colours on macOS before 26" {
  load_adapter
  export FAKE_SW_VERS_PRODUCT_VERSION=15.6
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "256 colours"
  unset FAKE_SW_VERS_PRODUCT_VERSION
  status=0; output="$(terminal_apply mocha 2>&1)" || status=$?
  assert_not_contains "$output" "256 colours"
}

# --- terminal_panel ----------------------------------------------------------

@test "terminal_panel pops up inside tmux and runs inline outside Terminal.app" {
  load_adapter
  status=0; output="$(TMUX=1 terminal_panel echo hi 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "tmux display-popup"
  status=0; output="$(terminal_panel echo hi 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  [ "$output" = "hi" ]
  [ ! -e "$CMD" ]
}

@test "terminal_panel inside Terminal.app writes the .command and opens a window on it" {
  load_adapter
  export TERM_PROGRAM=Apple_Terminal
  status=0; output="$(terminal_panel "$HOME/my player" --flag 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "open -a Terminal $CMD"
  assert_not_contains "$output" "tmux"
  [ -x "$CMD" ]
  grep -q "^exec $HOME/my\\\\ player --flag$" "$CMD"
  # tmux wins even inside Terminal.app.
  status=0; output="$(TMUX=1 terminal_panel echo hi 2>&1)" || status=$?
  assert_contains "$output" "tmux display-popup"
}

@test "terminal_panel in a dry run opens nothing and writes nothing" {
  load_adapter
  export TERM_PROGRAM=Apple_Terminal NEKOSHELL_DRY_RUN=1
  status=0; output="$(terminal_panel echo hi 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "would write $CMD"
  assert_contains "$output" "open -a Terminal"
  [ ! -e "$CMD" ]
}

# --- terminal_remove ---------------------------------------------------------

@test "terminal_remove restores the previous default, drops only the nekoshell profile and deletes the files" {
  seed_prefs
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  before="$(python3 -c 'import plistlib,sys; print(plistlib.load(open(sys.argv[1],"rb"))["Window Settings"]["Clear Dark"]["Font"].hex())' "$STORE")"
  status=0; output="$(terminal_remove 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_contains "$output" "Default Window Settings -string Clear Dark"
  assert_contains "$output" "Startup Window Settings -string Clear Dark"
  [ "$(prefs_summary)" = "Clear Dark Clear Dark Clear Dark " ]
  after="$(python3 -c 'import plistlib,sys; print(plistlib.load(open(sys.argv[1],"rb"))["Window Settings"]["Clear Dark"]["Font"].hex())' "$STORE")"
  [ "$before" = "$after" ]
  [ ! -e "$PROF" ]
  [ ! -e "$CMD" ]
  [ ! -e "$DIR" ]
}

@test "terminal_remove leaves a default the user has since changed alone" {
  seed_prefs
  load_adapter
  terminal_apply mocha >/dev/null 2>&1
  defaults write com.apple.Terminal "Default Window Settings" -string "Pro" >/dev/null
  status=0; output="$(terminal_remove 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "Default Window Settings -string"
  [ "$(prefs_summary)" = "Pro nekoshell Clear Dark " ]
}

@test "terminal_remove on a Mac nekoshell never touched changes nothing and succeeds" {
  seed_prefs
  load_adapter
  status=0; output="$(terminal_remove 2>&1)" || status=$?
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "defaults write"
  assert_not_contains "$output" "drop_profile"
  [ "$(prefs_summary)" = "Clear Dark Clear Dark Clear Dark " ]
}

# --- the doctor and the commands --------------------------------------------

@test "doctor fails the profile row before anything is applied" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  seed_prefs
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  run "$NK" doctor
  [ "$status" -eq 1 ]
  assert_matches "$output" 'fail +terminal-app profile +missing'
  assert_matches "$output" 'warn +terminal-app default +new windows open with Clear Dark'
  assert_matches "$output" 'warn +terminal-app font +no font to read'
  assert_matches "$output" 'ok +terminal-app colour +24-bit colour \(macOS 26\)'
}

@test "doctor passes every row after an apply" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  seed_prefs
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  "$NK" terminal apply >/dev/null 2>&1
  run "$NK" doctor
  [ "$status" -eq 0 ]
  assert_matches "$output" 'ok +terminal-app profile +nekoshell in Window Settings'
  assert_matches "$output" 'ok +terminal-app default +new windows open with nekoshell'
  assert_matches "$output" 'ok +terminal-app font +JetBrainsMonoNF-Regular'
  assert_matches "$output" 'ok +terminal-app colour'
}

@test "doctor warns on the default row while a Terminal.app that predates the profile is running" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  seed_prefs
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  "$NK" terminal apply >/dev/null 2>&1
  python3 - "$STORE" <<'PY'
import datetime, plistlib, sys
p = plistlib.load(open(sys.argv[1], "rb"))
p["LastTerminalStartTime"] = datetime.datetime(2001, 1, 1)
plistlib.dump(p, open(sys.argv[1], "wb"))
PY
  export FAKE_ITERM_RUNNING=1
  run "$NK" doctor
  [ "$status" -eq 0 ]
  assert_matches "$output" 'warn +terminal-app default +nekoshell, but the running Terminal.app started before it was installed; quit and reopen'
  unset FAKE_ITERM_RUNNING
  run "$NK" doctor
  assert_matches "$output" 'ok +terminal-app default +new windows open with nekoshell'
}

@test "doctor fails the font row when the installed profile uses another font" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  python3 "$GEN" --root "$REPO_ROOT" --out "$OUT" --font Menlo-Regular
  defaults write com.apple.Terminal "Window Settings" -dict-add nekoshell "$(cat "$OUT")" >/dev/null
  defaults write com.apple.Terminal "Default Window Settings" -string nekoshell >/dev/null
  run "$NK" doctor
  [ "$status" -eq 1 ]
  assert_matches "$output" 'ok +terminal-app profile'
  assert_matches "$output" 'fail +terminal-app font +Menlo-Regular is not JetBrainsMonoNF-Regular'
}

@test "doctor warns about 256 colours on macOS before 26" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  export FAKE_SW_VERS_PRODUCT_VERSION=14.7
  run "$NK" doctor
  assert_matches "$output" 'warn +terminal-app colour +256 colours only on macOS < 26 \(this is 14\)'
}

@test "nekoshell terminal use terminal-app records the terminal and installs the profile" {
  printf 'root = "%s"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  run "$NK" terminal use terminal-app
  [ "$status" -eq 0 ]
  [ -f "$PROF" ]
  grep -q 'terminal-app' "$HOME/.config/nekoshell/nekoshell.toml"
  [ "$(prefs_summary)" = "nekoshell nekoshell nekoshell JetBrainsMonoNF-Regular" ]
  run "$NK" terminal capabilities
  assert_contains "$output" "panel"
}

@test "nekoshell theme latte re-renders and re-installs the profile in latte" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  run "$NK" theme latte
  [ "$status" -eq 0 ]
  [ "$(rgb "$PROF" BackgroundColor)" = "239 241 245" ]
  run python3 - "$STORE" <<'PY'
import plistlib, sys
p = plistlib.load(open(sys.argv[1], "rb"))["Window Settings"]["nekoshell"]
c = plistlib.loads(p["BackgroundColor"])["$objects"][1]
print(" ".join(str(round(float(x) * 255)) for x in c["NSRGB"].rstrip(b"\x00").split()))
PY
  [ "$output" = "239 241 245" ]
}

@test "uninstall takes the profile out of Terminal.app and restores the default" {
  export NEKOSHELL_PLUGINS_DIR="$REPO_ROOT/tests/fixtures/plugins"
  seed_prefs
  ln -s "$REPO_ROOT/core/zsh/.zshrc" "$HOME/.zshrc"
  "$NK" terminal apply >/dev/null 2>&1
  [ -f "$PROF" ]
  run "$NK" uninstall --yes
  [ "$status" -eq 0 ]
  [ ! -e "$PROF" ]
  [ ! -e "$CMD" ]
  [ "$(prefs_summary)" = "Clear Dark Clear Dark Clear Dark " ]
}
