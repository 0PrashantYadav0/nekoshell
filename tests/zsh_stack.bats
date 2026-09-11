#!/usr/bin/env bats
load helpers

# A throwaway HOME means antidote's plugin cache is always cold, and `antidote
# load` would clone every plugin over the network. Point HOMEBREW_PREFIX at
# nothing so .zshrc finds no antidote and skips the block entirely.
setup() { setup_tmp_home; export HOMEBREW_PREFIX=/nonexistent; }
teardown() { teardown_tmp_home; }

stow_it() {
  mkdir -p "$HOME/.config/nekoshell/zsh"
  stow --no-folding -d "$REPO_ROOT/stow" -t "$HOME" zsh config
}

# Read values back by marker instead of by line number: the shell prints its
# own lines and the index is not ours to predict.
marker() { printf '%s\n' "$output" | sed -n "s/^$1=//p"; }

# render_starship FLAVOUR: render templates/starship.toml into $HOME the same
# way the installer does, so starship itself judges what a user actually gets.
render_starship() {
  bash -c "source '$REPO_ROOT/lib/log.sh'
           source '$REPO_ROOT/lib/paths.sh'
           NEKOSHELL_ROOT='$REPO_ROOT'
           source '$REPO_ROOT/lib/theme.sh'
           theme_render_template '$REPO_ROOT/templates/starship.toml' '$HOME/starship.toml' '$1'"
}

@test "zshrc parses and sets NEKOSHELL_ROOT and PATH from its stowed location" {
  stow_it
  run zsh -c 'source "$HOME/.zshrc"; echo "NEKO_ROOT=$NEKOSHELL_ROOT"; echo "NEKO_PATH=$PATH"'
  [ "$status" -eq 0 ]
  [ "$(marker NEKO_ROOT)" = "$REPO_ROOT" ]
  case "$(marker NEKO_PATH)" in
    "$REPO_ROOT/bin:$HOME/.local/bin:"*) : ;;
    *) echo "PATH does not start with the nekoshell bin: $(marker NEKO_PATH)" >&2; false ;;
  esac
}

@test "zshrc sources local.zsh when present" {
  stow_it
  mkdir -p "$HOME/.config/nekoshell/zsh"
  echo 'export NEKO_LOCAL_MARK=yes' > "$HOME/.config/nekoshell/zsh/local.zsh"
  run zsh -c 'source "$HOME/.zshrc"; echo "NEKO_MARK=$NEKO_LOCAL_MARK"'
  [ "$(marker NEKO_MARK)" = "yes" ]
}

@test "non-interactive zsh does not greet" {
  stow_it
  run zsh -c 'source "$HOME/.zshrc"; echo NEKO_DONE'
  [ "$status" -eq 0 ]
  assert_contains "$output" "NEKO_DONE"
  # The greeting writes this cache file whenever it draws anything.
  [ ! -e "$HOME/.cache/nekoshell/art-name" ]
}

# The starship config is rendered from templates/starship.toml, so the template
# carries all four palettes and a @@FLAVOR@@ placeholder on the palette line.
@test "starship template is valid TOML carrying all four Catppuccin palettes" {
  run python3 -c "
import tomllib,sys
d=tomllib.load(open('$REPO_ROOT/templates/starship.toml','rb'))
print(d['palette'])
print(' '.join(sorted(d['palettes'])))
print(d['palettes']['catppuccin_mocha']['mauve'], d['palettes']['catppuccin_latte']['base'])"
  [ "${lines[0]}" = "catppuccin_@@FLAVOR@@" ]
  [ "${lines[1]}" = "catppuccin_frappe catppuccin_latte catppuccin_macchiato catppuccin_mocha" ]
  [ "${lines[2]}" = "#cba6f7 #eff1f5" ]
}

@test "starship prompt is two lines with a full-path directory and a right-aligned clock" {
  run python3 -c "
import tomllib
d=tomllib.load(open('$REPO_ROOT/templates/starship.toml','rb'))
print(d['directory']['truncation_length'], d['directory']['truncate_to_repo'])
print('\$fill' in d['format'], '\$time' in d['format'], '\$status' in d['format'], '\$line_break' in d['format'], d['format'].rstrip().endswith('\$character'))
print(d['time']['disabled'], d['status']['disabled'])
print(d['format'].count(chr(10)))"
  [ "${lines[0]}" = "0 False" ]
  [ "${lines[1]}" = "True True True True True" ]
  [ "${lines[2]}" = "False False" ]
  # No newline embedded in the format value itself: $line_break must sit on
  # the same segment as $time, or a raw newline plus $line_break's own
  # newline render a blank row between the info line and the character.
  [ "${lines[3]}" = "0" ]
}

@test "starship prompt renders as exactly two lines after the add_newline blank line" {
  command -v starship >/dev/null || skip "starship not installed"
  render_starship mocha
  run bash -c "STARSHIP_CONFIG='$HOME/starship.toml' starship prompt --status=1 --cmd-duration=3500 --jobs=1 2>/dev/null | tail -n +2 | grep -c ''"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

@test "starship validates every rendered flavour" {
  command -v starship >/dev/null || skip "starship not installed"
  for flavour in frappe latte macchiato mocha; do
    render_starship "$flavour"
    grep -q "^palette = \"catppuccin_$flavour\"" "$HOME/starship.toml"
    run env STARSHIP_CONFIG="$HOME/starship.toml" starship print-config
    [ "$status" -eq 0 ]
  done
}

@test "zsh_migrate_aliases copies plain aliases and exports only" {
  cat > "$HOME/old.zshrc" <<'EOF'
export ZSH="$HOME/.oh-my-zsh"
plugins=(git)
alias gs='git status'
export EDITOR=vim
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
alias ohmyzsh="mate ~/.oh-my-zsh"
EOF
  run bash -c "source '$REPO_ROOT/lib/zsh_migrate.sh'; zsh_migrate_aliases '$HOME/old.zshrc' '$HOME/local.zsh'"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
  run cat "$HOME/local.zsh"
  assert_contains "$output" "alias gs='git status'"
  assert_contains "$output" "export EDITOR=vim"
  assert_not_contains "$output" "oh-my-zsh"
}

@test "zsh_migrate_aliases does not overwrite an existing destination" {
  echo 'alias keep=1' > "$HOME/local.zsh"
  echo "alias gs='git status'" > "$HOME/old.zshrc"
  run bash -c "source '$REPO_ROOT/lib/zsh_migrate.sh'; zsh_migrate_aliases '$HOME/old.zshrc' '$HOME/local.zsh'"
  [ "$output" = "0" ]
  run cat "$HOME/local.zsh"
  [ "$output" = "alias keep=1" ]
}
