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
print(p['Name'], p['Normal Font'], p['ASCII Ligatures'], p['Window Type'], p['Transparency'], p['Blur'], p['Blur Radius'], p['Use Cursor Guide'], p['Show Status Bar'])
print(round(bg['Red Component']*255), round(bg['Green Component']*255), round(bg['Blue Component']*255), bg['Color Space'])
print(round(p['Ansi 5 Color']['Red Component']*255), round(p['Ansi 5 Color']['Green Component']*255), round(p['Ansi 5 Color']['Blue Component']*255))
PY
  [ "${lines[0]}" = "nekoshell JetBrainsMonoNF-Regular 15 True 0 0.1 True 24 True True" ]
  [ "${lines[1]}" = "30 30 46 sRGB" ]
  [ "${lines[2]}" = "245 194 231" ]
}

@test "--flavor picks another Catppuccin palette" {
  python3 "$REPO_ROOT/iterm2/build-profiles.py" --root "$REPO_ROOT" --out "$OUT" --flavor latte
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
  run python3 "$REPO_ROOT/iterm2/build-profiles.py" --root "$REPO_ROOT" --out "$OUT" --flavor dracula
  [ "$status" -ne 0 ]
  [ ! -f "$OUT" ]
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
