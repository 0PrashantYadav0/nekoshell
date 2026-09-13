# gh

## What it does

Installs [gh](https://cli.github.com), GitHub's command line, and wires it
into the shell: tab completion for every subcommand, generated once and
cached under `~/.cache/nekoshell/` so a new shell does not wait for it, and
`delta` as the pager for `gh pr diff` when the modern-cli plugin has put it
on PATH. Your `~/.config/gh/` is not touched: aliases, editor and protocol
stay whatever `gh config` set.

## Installs

`gh` (Homebrew formula).

## Files

None in your home. `~/.cache/nekoshell/gh-completion.zsh` is regenerated
whenever gh is newer than it.

## After install

`gh auth login` once, if you have not. The doctor warns until you do.

## Remove

`nekoshell plugin remove gh` takes the completions and the pager setting
away; `--purge` uninstalls gh too, as long as no other enabled plugin needs
it. Your `~/.config/gh/` stays.
