#!/usr/bin/env bats
load helpers

setup() { setup_tmp_home; }
teardown() { teardown_tmp_home; }

stow_it() {
  mkdir -p "$HOME/.config/nekoshell/zsh"
  stow --no-folding -d "$REPO_ROOT/stow" -t "$HOME" zsh config
}

@test "zshrc parses and sets NEKOSHELL_ROOT and PATH from its stowed location" {
  stow_it
  run zsh -c 'source "$HOME/.zshrc"; echo "$NEKOSHELL_ROOT"; echo "$PATH"'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$REPO_ROOT" ]
  [[ "${lines[1]}" == "$REPO_ROOT/bin:$HOME/.local/bin:"* ]]
}

@test "zshrc sources local.zsh when present" {
  stow_it
  mkdir -p "$HOME/.config/nekoshell/zsh"
  echo 'export NEKO_LOCAL_MARK=yes' > "$HOME/.config/nekoshell/zsh/local.zsh"
  run zsh -c 'source "$HOME/.zshrc"; echo "$NEKO_LOCAL_MARK"'
  [ "$output" = "yes" ]
}

@test "non-interactive zsh does not greet" {
  stow_it
  run zsh -c 'source "$HOME/.zshrc"; echo done'
  [ "$output" = "done" ]
}

@test "starship config is valid TOML with the mocha palette" {
  run python3 -c "
import tomllib,sys
d=tomllib.load(open('$REPO_ROOT/stow/config/.config/starship.toml','rb'))
print(d['palette']); print(d['palettes']['catppuccin_mocha']['mauve'])"
  [ "${lines[0]}" = "catppuccin_mocha" ]
  [ "${lines[1]}" = "#cba6f7" ]
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
  [[ "$output" == *"alias gs='git status'"* ]]
  [[ "$output" == *"export EDITOR=vim"* ]]
  [[ "$output" != *"oh-my-zsh"* ]]
}

@test "zsh_migrate_aliases does not overwrite an existing destination" {
  echo 'alias keep=1' > "$HOME/local.zsh"
  echo "alias gs='git status'" > "$HOME/old.zshrc"
  run bash -c "source '$REPO_ROOT/lib/zsh_migrate.sh'; zsh_migrate_aliases '$HOME/old.zshrc' '$HOME/local.zsh'"
  [ "$output" = "0" ]
  run cat "$HOME/local.zsh"
  [ "$output" = "alias keep=1" ]
}
