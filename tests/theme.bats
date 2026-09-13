#!/usr/bin/env bats
load helpers

setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_SKIP_PREFLIGHT=1
  "$REPO_ROOT/install.sh" --yes >/dev/null
}
teardown() { teardown_tmp_home; }

@test "palettes.json has four flavours with the known bases" {
  run python3 -c "
import json; d=json.load(open('$REPO_ROOT/data/palettes.json'))
print(sorted(d)); print(d['mocha']['base'], d['latte']['base'], len(d['mocha']))"
  [ "${lines[0]}" = "['frappe', 'latte', 'macchiato', 'mocha']" ]
  [ "${lines[1]}" = "1e1e2e eff1f5 26" ]
}

@test "install renders mocha by default" {
  [ "$(cat "$HOME/.config/nekoshell/theme")" = "mocha" ]
  [ ! -L "$HOME/.config/starship.toml" ]
  grep -q '^palette = "catppuccin_mocha"' "$HOME/.config/starship.toml"
  grep -q '38;2;203;166;247' "$HOME/.config/fastfetch/config.jsonc"
  grep -q 'BAT_THEME="Catppuccin Mocha"' "$HOME/.config/nekoshell/theme.zsh"
}

@test "nekoshell-theme latte re-renders every themed file" {
  run "$REPO_ROOT/bin/nekoshell-theme" latte
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.config/nekoshell/theme")" = "latte" ]
  grep -q '^palette = "catppuccin_latte"' "$HOME/.config/starship.toml"
  grep -q 'BAT_THEME="Catppuccin Latte"' "$HOME/.config/nekoshell/theme.zsh"
  grep -q 'color_theme = "catppuccin_latte"' "$HOME/.config/btop/btop.conf"
  run python3 -c "
import json; p=json.load(open('$HOME/Library/Application Support/iTerm2/DynamicProfiles/nekoshell.json'))['Profiles'][0]
bg=p['Background Color']; print(round(bg['Red Component']*255), round(bg['Green Component']*255), round(bg['Blue Component']*255))"
  [ "$output" = "239 241 245" ]
}

@test "nekoshell-theme rejects unknown flavours and lists the known ones" {
  run "$REPO_ROOT/bin/nekoshell-theme" dracula
  [ "$status" -ne 0 ]
  run "$REPO_ROOT/bin/nekoshell-theme" list
  [ "$output" = $'frappe\nlatte\nmacchiato\nmocha' ]
  run "$REPO_ROOT/bin/nekoshell-theme" current
  [ "$output" = "mocha" ]
}

# Before this change starship.toml and the fastfetch config were stowed. `stow
# --restow` only unlinks what the package still holds, so an upgraded machine
# keeps the old symlink, and rendering through it would write into the checkout.
# Both shapes are covered: one link whose target still exists (the file moved to
# templates/) and one left dangling at the path the package used to hold.
@test "an upgrade replaces the old stowed symlinks instead of writing through them" {
  ln -sfn "$REPO_ROOT/templates/starship.toml" "$HOME/.config/starship.toml"
  ln -sfn "$REPO_ROOT/stow/config/.config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
  "$REPO_ROOT/install.sh" --yes >/dev/null
  [ ! -L "$HOME/.config/starship.toml" ]
  [ ! -L "$HOME/.config/fastfetch/config.jsonc" ]
  grep -q '@@FLAVOR@@' "$REPO_ROOT/templates/starship.toml"
  assert_not_contains "$(cat "$HOME/.config/starship.toml")" '@@FLAVOR@@'
}

# stow writes RELATIVE links, and this version deleted the directory the
# fastfetch one pointed through, so that link cannot be resolved by following it.
# Left in place it took `nekoshell-theme` down mid-render: the recorded flavour,
# theme.zsh and btop.conf had already moved while the fastfetch config and the
# iTerm2 profile stayed on the old flavour.
@test "a theme switch survives the relative stow links an upgrade leaves behind" {
  rm -f "$HOME/.config/starship.toml" "$HOME/.config/fastfetch/config.jsonc"
  # ~/.config/starship.toml -> ../../<checkout>/templates/starship.toml
  ln -s "$(relpath "$REPO_ROOT/templates/starship.toml" "$HOME/.config")" \
    "$HOME/.config/starship.toml"
  # ~/.config/fastfetch/config.jsonc -> a path whose directory no longer exists
  ln -s "$(relpath "$REPO_ROOT/stow/config/.config/fastfetch/config.jsonc" "$HOME/.config/fastfetch")" \
    "$HOME/.config/fastfetch/config.jsonc"
  [ -L "$HOME/.config/fastfetch/config.jsonc" ]
  [ ! -e "$HOME/.config/fastfetch/config.jsonc" ]

  run "$REPO_ROOT/bin/nekoshell-theme" latte
  [ "$status" -eq 0 ]

  for f in "$HOME/.config/starship.toml" "$HOME/.config/fastfetch/config.jsonc"; do
    [ ! -L "$f" ]
    [ -f "$f" ]
  done
  grep -q '^palette = "catppuccin_latte"' "$HOME/.config/starship.toml"
  grep -q '38;2;136;57;239' "$HOME/.config/fastfetch/config.jsonc"
  [ "$(cat "$HOME/.config/nekoshell/theme")" = "latte" ]
  # The profile has to move with the rest, not stay on the old flavour.
  run python3 -c "
import json; p=json.load(open('$HOME/Library/Application Support/iTerm2/DynamicProfiles/nekoshell.json'))['Profiles'][0]
bg=p['Background Color']; print(round(bg['Red Component']*255), round(bg['Green Component']*255), round(bg['Blue Component']*255))"
  [ "$output" = "239 241 245" ]
  # The checkout must not have been written through either link.
  grep -q '@@FLAVOR@@' "$REPO_ROOT/templates/starship.toml"
}

# A link of the user's own to a real file elsewhere is not stow's leftover and
# must survive: only a link into the checkout or a broken one is cleared.
@test "a re-install leaves the user's own symlinked starship config alone" {
  echo '# theirs' > "$HOME/mine.toml"
  rm -f "$HOME/.config/starship.toml"
  ln -s "$HOME/mine.toml" "$HOME/.config/starship.toml"
  "$REPO_ROOT/install.sh" --yes >/dev/null
  [ -L "$HOME/.config/starship.toml" ]
  [ "$(cat "$HOME/.config/starship.toml")" = "# theirs" ]
}

@test "a user edit to starship.toml survives a re-install but not a theme switch" {
  echo '# mine' >> "$HOME/.config/starship.toml"
  "$REPO_ROOT/install.sh" --yes >/dev/null
  grep -q '# mine' "$HOME/.config/starship.toml"
  "$REPO_ROOT/bin/nekoshell-theme" mocha >/dev/null
  assert_not_contains "$(cat "$HOME/.config/starship.toml")" '# mine'
}
