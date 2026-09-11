#!/usr/bin/env bats
load helpers

# The polish set: fzf previews, themed syntax highlighting, atuin, and the
# iTerm2 status bar. Everything here is functional first, so every test asks
# what a shell or iTerm2 would actually read, not what the file looks like.

setup() {
  setup_tmp_home
  export HOMEBREW_PREFIX=/nonexistent
  ZDIR="$REPO_ROOT/stow/config/.config/nekoshell/zsh"
}
teardown() { teardown_tmp_home; }

stow_it() {
  mkdir -p "$HOME/.config/nekoshell/zsh"
  stow --no-folding -d "$REPO_ROOT/stow" -t "$HOME" zsh config
}

marker() { printf '%s\n' "$output" | sed -n "s/^$1=//p"; }

# has NEEDLE: the captured output contains NEEDLE. A bare `[[ ]]` in the middle
# of a test does not fail the test under bats, so substring assertions go
# through a real command, whose non-zero status does stop the test.
has() { printf '%s\n' "$output" | grep -qF -- "$1"; }
hasnt() { ! printf '%s\n' "$output" | grep -qF -- "$1"; }
# marker_has KEY NEEDLE: the value printed as KEY=... contains NEEDLE.
marker_has() { marker "$1" | grep -qF -- "$2"; }

# --- 1. fzf previews ---------------------------------------------------------

@test "fzf.zsh parses as zsh" {
  run zsh -n "$ZDIR/fzf.zsh"
  [ "$status" -eq 0 ]
}

@test "fzf.zsh sets a preview for each of the three fzf bindings" {
  stow_it
  run zsh -c 'source "$HOME/.config/nekoshell/zsh/fzf.zsh"
    echo "CTRL_T=$FZF_CTRL_T_OPTS"
    echo "ALT_C=$FZF_ALT_C_OPTS"
    echo "CTRL_R=$FZF_CTRL_R_OPTS"'
  [ "$status" -eq 0 ]
  marker_has CTRL_T 'bat --color=always'
  marker_has CTRL_T '--preview-window=right:60%'
  marker_has ALT_C 'eza --tree --level=2'
  marker_has CTRL_R '--preview-window=down:3:wrap'
}

# fd is the only one of these that changes what fzf lists rather than how it
# previews, so it has to be conditional: without fd, fzf's own default walk.
@test "FZF_DEFAULT_COMMAND is set only when fd is on PATH" {
  stow_it
  mkdir -p "$HOME/fakebin"
  printf '#!/bin/sh\nexit 0\n' > "$HOME/fakebin/fd"
  chmod +x "$HOME/fakebin/fd"
  run zsh -c 'PATH="$HOME/fakebin:$PATH"; source "$HOME/.config/nekoshell/zsh/fzf.zsh"; echo "CMD=$FZF_DEFAULT_COMMAND"'
  [ "$(marker CMD)" = "fd --type f --hidden --follow --exclude .git" ]
  run zsh -c 'PATH=/nonexistent; source "$HOME/.config/nekoshell/zsh/fzf.zsh"; echo "CMD=${FZF_DEFAULT_COMMAND-unset}"'
  [ "$(marker CMD)" = "unset" ]
}

@test "fzf-tab previews directories and reuses the themed fzf defaults" {
  stow_it
  run zsh -c 'source "$HOME/.config/nekoshell/zsh/fzf.zsh"
    zstyle -s ":fzf-tab:complete:cd:*" fzf-preview v; echo "PREVIEW=$v"
    zstyle -s ":fzf-tab:*" use-fzf-default-opts w; echo "DEFAULTS=$w"'
  marker_has PREVIEW 'eza --icons --color=always -1 '
  [ "$(marker DEFAULTS)" = "yes" ]
}

@test "zshrc still sources cleanly with the new lines and picks up fzf.zsh" {
  stow_it
  run zsh -c 'source "$HOME/.zshrc"; echo "CTRL_T=$FZF_CTRL_T_OPTS"; echo NEKO_DONE'
  [ "$status" -eq 0 ]
  has NEKO_DONE
  marker_has CTRL_T 'bat --color=always'
}

# --- 2. themed syntax highlighting -------------------------------------------

@test "all four Catppuccin highlighting themes are vendored and define styles" {
  for f in frappe latte macchiato mocha; do
    p="$REPO_ROOT/data/zsh-syntax-highlighting/catppuccin_$f-zsh-syntax-highlighting.zsh"
    [ -r "$p" ]
    run zsh -n "$p"
    [ "$status" -eq 0 ]
    grep -q 'ZSH_HIGHLIGHT_STYLES' "$p"
  done
  grep -qF 'zsh-syntax-highlighting' "$REPO_ROOT/THIRD_PARTY.md"
}

@test "theme.zsh loads the flavour's highlighting theme and tints autosuggestions" {
  run bash -c "source '$REPO_ROOT/lib/log.sh'
    source '$REPO_ROOT/lib/paths.sh'
    NEKOSHELL_ROOT='$REPO_ROOT'
    source '$REPO_ROOT/lib/theme.sh'
    mkdir -p \"\$NEKOSHELL_CONFIG\"
    theme_write_zsh macchiato"
  [ "$status" -eq 0 ]
  grep -qF "data/zsh-syntax-highlighting/catppuccin_macchiato-zsh-syntax-highlighting.zsh" \
    "$HOME/.config/nekoshell/theme.zsh"
  # macchiato overlay0
  grep -qF 'ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6e738d"' "$HOME/.config/nekoshell/theme.zsh"
  run zsh -n "$HOME/.config/nekoshell/theme.zsh"
  [ "$status" -eq 0 ]
}

# The plugin reads ZSH_HIGHLIGHT_STYLES when it loads, so the theme has to be
# in the environment before antidote pulls the plugins in. env.zsh sources
# theme.zsh, and env.zsh is sourced above the antidote block.
@test "theme.zsh is sourced before antidote loads the plugins" {
  env_line="$(grep -n 'zsh/env\.zsh' "$REPO_ROOT/stow/zsh/.zshrc" | head -1 | cut -d: -f1)"
  antidote_line="$(grep -n 'antidote load' "$REPO_ROOT/stow/zsh/.zshrc" | head -1 | cut -d: -f1)"
  [ -n "$env_line" ]
  [ -n "$antidote_line" ]
  [ "$env_line" -lt "$antidote_line" ]
  grep -q 'theme\.zsh' "$REPO_ROOT/stow/config/.config/nekoshell/zsh/env.zsh"
}

@test "a real shell ends up with the flavour's highlight styles set" {
  stow_it
  bash -c "source '$REPO_ROOT/lib/log.sh'
    source '$REPO_ROOT/lib/paths.sh'
    NEKOSHELL_ROOT='$REPO_ROOT'
    source '$REPO_ROOT/lib/theme.sh'
    theme_write_zsh mocha"
  run zsh -c 'source "$HOME/.zshrc"; echo "CMD=$ZSH_HIGHLIGHT_STYLES[command]"; echo "SUGGEST=$ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE"'
  [ "$status" -eq 0 ]
  [ "$(marker CMD)" = "fg=#a6e3a1" ]
  [ "$(marker SUGGEST)" = "fg=#6c7086" ]
}

# --- 3. atuin ----------------------------------------------------------------

@test "atuin config is valid TOML and stays offline" {
  run python3 -c "
import tomllib
d = tomllib.load(open('$REPO_ROOT/stow/config/.config/atuin/config.toml','rb'))
print(d['auto_sync'], d['update_check'])
print(d['style'], d['inline_height'], d['search_mode'], d['filter_mode_shell_up_key_binding'])"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "False False" ]
  [ "${lines[1]}" = "compact 20 fuzzy session" ]
}

@test "zshrc initialises atuin without stealing the up arrow" {
  grep -q 'atuin init zsh --disable-up-arrow' "$REPO_ROOT/stow/zsh/.zshrc"
  # After fzf, so atuin's Ctrl-R binding is the one that survives.
  fzf_line="$(grep -n 'fzf --zsh' "$REPO_ROOT/stow/zsh/.zshrc" | head -1 | cut -d: -f1)"
  atuin_line="$(grep -n 'atuin init' "$REPO_ROOT/stow/zsh/.zshrc" | head -1 | cut -d: -f1)"
  [ "$fzf_line" -lt "$atuin_line" ]
}

@test "atuin is in the Brewfile and in the doctor's tool list" {
  grep -q '^brew "atuin"' "$REPO_ROOT/Brewfile"
  grep -q 'atuin' "$REPO_ROOT/bin/nekoshell-doctor"
}

@test "the doctor reports atuin as a tool" {
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_SKIP_PREFLIGHT=1
  "$REPO_ROOT/install.sh" --yes >/dev/null
  run "$REPO_ROOT/bin/nekoshell-doctor"
  has "tool: atuin"
  hasnt "fail tool: atuin"
}

# --- 4. iTerm2 status bar and profile extras ---------------------------------

@test "main profile turns on the cursor guide and the status bar" {
  python3 "$REPO_ROOT/iterm2/build-profiles.py" --root "$REPO_ROOT" --out "$HOME/p.json"
  run python3 - "$HOME/p.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))['Profiles'][0]
print(p['Use Cursor Guide'], p['Show Status Bar'])
PY
  [ "$output" = "True True" ]
}

@test "the status bar layout lists the seven components left to right" {
  python3 "$REPO_ROOT/iterm2/build-profiles.py" --root "$REPO_ROOT" --out "$HOME/p.json"
  run python3 - "$HOME/p.json" <<'PY'
import json, sys
layout = json.load(open(sys.argv[1]))['Profiles'][0]['Status Bar Layout']
comps = layout['components']
print(len(comps))
for c in comps:
    print(c['class'], 'knobs' in c['configuration'])
PY
  [ "${lines[0]}" = "7" ]
  [ "${lines[1]}" = "iTermStatusBarWorkingDirectoryComponent True" ]
  [ "${lines[2]}" = "iTermStatusBarGitComponent True" ]
  [ "${lines[3]}" = "iTermStatusBarSpringComponent True" ]
  [ "${lines[4]}" = "iTermStatusBarCPUUtilizationComponent True" ]
  [ "${lines[5]}" = "iTermStatusBarMemoryUtilizationComponent True" ]
  [ "${lines[6]}" = "iTermStatusBarBatteryComponent True" ]
  [ "${lines[7]}" = "iTermStatusBarClockComponent True" ]
}

# The advanced configuration is where iTerm2 reads the bar's own colours, and
# they have to move with the flavour like every other colour in the rig.
@test "the status bar wears the flavour's mantle, text and surface1" {
  python3 "$REPO_ROOT/iterm2/build-profiles.py" --root "$REPO_ROOT" --out "$HOME/p.json" --flavor latte
  run python3 - "$HOME/p.json" <<'PY'
import json, sys
adv = json.load(open(sys.argv[1]))['Profiles'][0]['Status Bar Layout']['advanced configuration']
def rgb(d):
    return "%d %d %d %s" % (round(d['Red Component'] * 255), round(d['Green Component'] * 255),
                            round(d['Blue Component'] * 255), d['Color Space'])
print(rgb(adv['background color']))
print(rgb(adv['default text color']))
print(rgb(adv['separator color 2']))
PY
  # latte mantle e6e9ef, text 4c4f69, surface1 bcc0cc
  [ "${lines[0]}" = "230 233 239 sRGB" ]
  [ "${lines[1]}" = "76 79 105 sRGB" ]
  [ "${lines[2]}" = "188 192 204 sRGB" ]
}

# The panel is a 60-column Spotify window. A status bar there would eat a row
# for nothing, so only the main profile gets one.
@test "the panel profile has no status bar" {
  python3 "$REPO_ROOT/iterm2/build-profiles.py" --root "$REPO_ROOT" --out "$HOME/p.json"
  run python3 -c "
import json; p = json.load(open('$HOME/p.json'))['Profiles'][1]
print(p['Show Status Bar'], 'Status Bar Layout' in p)"
  [ "$output" = "False False" ]
}

@test "inactive split panes are dimmed through the global prefs" {
  run bash -c "NEKOSHELL_DRY_RUN=1; export NEKOSHELL_DRY_RUN
    source '$REPO_ROOT/lib/log.sh'; source '$REPO_ROOT/lib/paths.sh'; source '$REPO_ROOT/lib/iterm.sh'
    iterm_apply_prefs"
  [ "$status" -eq 0 ]
  has "DimInactiveSplitPanes -bool true"
  has "SplitPaneDimmingAmount -float 0.3"
}

# The working directory and git components only ever have something to show
# once iTerm2's shell integration is reporting from the shell.
@test "shell integration is downloaded, sourced, backed up and left behind" {
  grep -q 'iterm2_shell_integration.zsh' "$REPO_ROOT/stow/zsh/.zshrc"
  grep -q 'iterm2.com/shell_integration/zsh' "$REPO_ROOT/install.sh"
  grep -q 'iterm2_shell_integration' "$REPO_ROOT/uninstall.sh"
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_SKIP_PREFLIGHT=1
  echo 'mine' > "$HOME/.iterm2_shell_integration.zsh"
  run "$REPO_ROOT/install.sh" --yes --skip-brew
  [ "$status" -eq 0 ]
  has "curl -fsSL https://iterm2.com/shell_integration/zsh"
  [ -f "$HOME/.iterm2_shell_integration.zsh" ]
  # The file the user already had is saved, like every other file replaced.
  backup="$(ls -d "$HOME"/.local/share/nekoshell/backup/*/ | head -1)"
  [ "$(cat "$backup/.iterm2_shell_integration.zsh")" = "mine" ]
}

@test "--check does not download the shell integration" {
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_SKIP_PREFLIGHT=1
  run "$REPO_ROOT/install.sh" --check
  [ "$status" -eq 0 ]
  hasnt "curl"
  [ ! -e "$HOME/.iterm2_shell_integration.zsh" ]
}

@test "--dry-run does not download the shell integration" {
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_SKIP_PREFLIGHT=1
  run "$REPO_ROOT/install.sh" --dry-run --yes
  [ "$status" -eq 0 ]
  has "curl -fsSL https://iterm2.com/shell_integration/zsh"
  [ ! -e "$HOME/.iterm2_shell_integration.zsh" ]
}

# --- R21: bat only sees the vendored themes after its cache is built ---------

@test "the installer builds bat's theme cache" {
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_SKIP_PREFLIGHT=1
  run "$REPO_ROOT/install.sh" --yes
  [ "$status" -eq 0 ]
  has "bat cache --build"
}

# nekoshell-theme sends the render's own output to /dev/null, so the cache
# rebuild is checked where it happens rather than through the command's stdout.
@test "a theme switch rebuilds bat's theme cache" {
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_SKIP_PREFLIGHT=1
  "$REPO_ROOT/install.sh" --yes >/dev/null
  run bash -c "source '$REPO_ROOT/lib/log.sh'; source '$REPO_ROOT/lib/paths.sh'
    NEKOSHELL_ROOT='$REPO_ROOT'
    source '$REPO_ROOT/lib/backup.sh'; source '$REPO_ROOT/lib/iterm.sh'
    source '$REPO_ROOT/lib/theme.sh'
    theme_apply latte overwrite no-profile"
  [ "$status" -eq 0 ]
  has "bat cache --build"
  [ "$(cat "$HOME/.config/nekoshell/theme")" = "latte" ]
  # And the switch really did move the flavour's highlighting theme with it.
  grep -qF 'catppuccin_latte-zsh-syntax-highlighting.zsh' "$HOME/.config/nekoshell/theme.zsh"
}

@test "a dry-run theme render does not build bat's cache" {
  run bash -c "NEKOSHELL_DRY_RUN=1; export NEKOSHELL_DRY_RUN
    source '$REPO_ROOT/lib/log.sh'; source '$REPO_ROOT/lib/paths.sh'
    NEKOSHELL_ROOT='$REPO_ROOT'
    source '$REPO_ROOT/lib/backup.sh'; source '$REPO_ROOT/lib/iterm.sh'
    source '$REPO_ROOT/lib/theme.sh'
    theme_apply mocha overwrite no-profile"
  [ "$status" -eq 0 ]
  hasnt "bat cache"
}

@test "the doctor reports the bat theme row" {
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_SKIP_PREFLIGHT=1
  "$REPO_ROOT/install.sh" --yes >/dev/null
  run "$REPO_ROOT/bin/nekoshell-doctor"
  has "ok   bat theme"
}

# bat is optional as far as the doctor is concerned: it has its own tool row,
# and a second failure for the same missing binary tells nobody anything new.
@test "the bat theme row is skipped when bat is missing" {
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_SKIP_PREFLIGHT=1
  "$REPO_ROOT/install.sh" --yes >/dev/null
  mkdir -p "$HOME/nobat"
  for t in "$REPO_ROOT"/tests/fakes/*; do
    case "$(basename "$t")" in bat) ;; *) ln -sf "$t" "$HOME/nobat/" ;; esac
  done
  run env PATH="$HOME/nobat:/usr/bin:/bin" "$REPO_ROOT/bin/nekoshell-doctor"
  hasnt "bat theme"
}
