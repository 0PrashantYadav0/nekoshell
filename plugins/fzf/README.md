# fzf

## What it does

Turns on [fzf](https://github.com/junegunn/fzf)'s three key bindings and gives
each of them something to look at:

- **Ctrl-T** — files, previewed with `bat` (the first 200 lines, so a huge file
  stays cheap)
- **Alt-C** — directories, previewed as two levels of `eza --tree`
- **Ctrl-R** — history, previewed as the command itself, wrapped, so a long
  one-liner is not cut off at the width of the list

Tab completion goes through `fzf-tab` (which the core already loads) and reuses
the same colours.

Colours come from `FZF_DEFAULT_OPTS`, which `nekoshell theme` renders, so the
finder follows the flavour without any setting of its own.

## Installs

`fzf` (Homebrew formula).

## Files

Nothing in your home. The previews live in `plugins/fzf/fzf.zsh`, sourced from
`plugin.zsh` after `fzf --zsh` has installed the bindings themselves.

With the `modern-cli` plugin also enabled, `fd` becomes fzf's file walker
(`FZF_DEFAULT_COMMAND`), which is faster than the built-in walk and honours
`.gitignore`.

## After install

Nothing. Open a new shell and press Ctrl-T.

## Remove

`nekoshell plugin remove fzf`. Add `purge` to uninstall the formula too, as
long as no other enabled plugin needs it.
