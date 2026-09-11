#!/usr/bin/env bats
load helpers

# AeroSpace tiles macOS windows (i3-style); tmux tiles panes inside one
# terminal window. The two sit beside each other. AeroSpace is opt-in because
# it needs the Accessibility permission and its own Homebrew tap, so it must
# never be part of the default install: `./install.sh --aerospace` is the only
# way any of this runs.

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_SKIP_PREFLIGHT=1
}
teardown() { teardown_tmp_home; }

@test "Brewfile.aerospace taps nikitabobko and installs the cask" {
  grep -q '^tap "nikitabobko/tap"$' "$REPO_ROOT/Brewfile.aerospace"
  grep -q '^cask "nikitabobko/tap/aerospace"$' "$REPO_ROOT/Brewfile.aerospace"
}

# The tap must stay out of the main Brewfile: tapping it is exactly what makes
# --aerospace opt-in rather than something every install does.
@test "the default Brewfile never mentions AeroSpace or its tap" {
  run grep -c 'aerospace' "$REPO_ROOT/Brewfile"
  [ "$output" = "0" ]
}

@test "a default install does not touch AeroSpace at all" {
  run "$REPO_ROOT/install.sh" --yes
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "Brewfile.aerospace"
  [ ! -e "$HOME/.config/aerospace" ]
}

@test "--aerospace bundles Brewfile.aerospace, copies the config, and prints the Accessibility step" {
  run "$REPO_ROOT/install.sh" --yes --aerospace
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew bundle --file $REPO_ROOT/Brewfile.aerospace"
  [ -f "$HOME/.config/aerospace/aerospace.toml" ]
  [ ! -L "$HOME/.config/aerospace/aerospace.toml" ]
  grep -q 'nekoshell AeroSpace config' "$HOME/.config/aerospace/aerospace.toml"
  assert_contains "$output" "Accessibility"
}

@test "a pre-existing AeroSpace config is backed up before nekoshell's first --aerospace run" {
  mkdir -p "$HOME/.config/aerospace"
  echo '# my own aerospace config' > "$HOME/.config/aerospace/aerospace.toml"
  run "$REPO_ROOT/install.sh" --yes --aerospace
  [ "$status" -eq 0 ]
  backup="$(ls -d "$HOME"/.local/share/nekoshell/backup/*/ | head -1)"
  [ "$(cat "$backup/.config/aerospace/aerospace.toml")" = "# my own aerospace config" ]
  grep -q '^\.config/aerospace/aerospace\.toml$' "$backup/manifest.txt"
  grep -q 'nekoshell AeroSpace config' "$HOME/.config/aerospace/aerospace.toml"
}

@test "a re-install with --aerospace keeps your edit" {
  "$REPO_ROOT/install.sh" --yes --aerospace >/dev/null
  echo '# mine' >> "$HOME/.config/aerospace/aerospace.toml"
  run "$REPO_ROOT/install.sh" --yes --aerospace
  [ "$status" -eq 0 ]
  grep -q '# mine' "$HOME/.config/aerospace/aerospace.toml"
}

# The re-install above never had anything of the user's to back up in the
# first place (a fresh HOME has no aerospace.toml at all). This test starts
# from a real pre-existing config instead, so the backup from that first run
# is the only one: the second --aerospace run must not treat its own,
# already-marked file as foreign and back it up again.
@test "a second --aerospace run does not re-back-up its own config" {
  mkdir -p "$HOME/.config/aerospace"
  echo '# my own aerospace config' > "$HOME/.config/aerospace/aerospace.toml"
  "$REPO_ROOT/install.sh" --yes --aerospace >/dev/null
  run "$REPO_ROOT/install.sh" --yes --aerospace
  [ "$status" -eq 0 ]
  [ "$(ls -d "$HOME"/.local/share/nekoshell/backup/*/ | wc -l | tr -d ' ')" = "1" ]
  grep -q 'nekoshell AeroSpace config' "$HOME/.config/aerospace/aerospace.toml"
}

@test "--dry-run --aerospace creates nothing" {
  run "$REPO_ROOT/install.sh" --dry-run --yes --aerospace
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.config/aerospace" ]
  [ ! -d "$HOME/.local/share/nekoshell/backup" ]
}

@test "the AeroSpace template parses as toml, floats the panel, and never binds alt-m" {
  run python3 -c "
import tomllib
with open('$REPO_ROOT/templates/aerospace/aerospace.toml', 'rb') as f:
    data = tomllib.load(f)
binding = data['mode']['main']['binding']
assert 'alt-m' not in binding, 'alt-m is reserved for the Spotify panel'
rules = data['on-window-detected']
assert any(
    r.get('if', {}).get('app-id') == 'com.googlecode.iterm2'
    and 'nekoshell panel' in r.get('if', {}).get('window-title-regex-substring', '')
    and r.get('run') == 'layout floating'
    for r in rules
), 'missing the panel float rule'
print('ok')
"
  [ "$status" -eq 0 ]
  assert_contains "$output" "ok"
}

@test "the doctor warns when AeroSpace is not installed" {
  run env PATH="/usr/bin:/bin:/usr/sbin:/sbin" "$REPO_ROOT/bin/nekoshell-doctor"
  assert_matches "$output" 'warn[[:space:]]+aerospace'
  assert_contains "$output" "install.sh --aerospace"
}

@test "the doctor reports aerospace ok with the fake tool" {
  run env PATH="$REPO_ROOT/tests/fakes:/usr/bin:/bin:/usr/sbin:/sbin" "$REPO_ROOT/bin/nekoshell-doctor"
  assert_matches "$output" 'ok[[:space:]]+aerospace'
}

# The row format is `printf '%-4s %-28s %s\n'`, so a failing row reads
# "fail aerospace" with exactly one space between "fail" and the check name
# (no padding needed: "fail" is already 4 characters); the aerospace row
# never goes through the "tool: X" loop, so that shape can never occur here
# either way. Asserting the reachable "fail" shape, and that the row is
# actually present as a warn, is what makes this test able to fail.
@test "the doctor never fails because AeroSpace is missing" {
  run env PATH="/usr/bin:/bin:/usr/sbin:/sbin" "$REPO_ROOT/bin/nekoshell-doctor"
  assert_not_contains "$output" "fail aerospace"
  assert_matches "$output" 'warn[[:space:]]+aerospace'
}
