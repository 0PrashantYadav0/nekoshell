# lazygit

## What it does

Adds [lazygit](https://github.com/jesseduffield/lazygit), a terminal UI for
git: stage a hunk, amend, rebase, cherry-pick and read the log without leaving
the keyboard. `lg` opens it.

Diffs inside it are paged through `delta`, so they read the same way
`git diff` does with the `modern-cli` plugin enabled.

## Installs

`lazygit` (Homebrew formula).

## Files

Symlinked into your home:

- `~/.config/lazygit/config.yml` — Catppuccin Mocha borders and highlights,
  Nerd Fonts v3 icons, `delta` as the pager

## After install

Nothing. Open a new shell and type `lg` inside a repository.

## Remove

`nekoshell plugin remove lazygit` unlinks the config. Add `--purge` to uninstall
the formula too, as long as no other enabled plugin needs it.
