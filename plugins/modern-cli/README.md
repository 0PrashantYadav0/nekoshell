# modern-cli

## What it does

Replaces the tools you reach for most with the ones that are nicer to read:
`ls` becomes [eza](https://github.com/eza-community/eza) with icons, `cat`
becomes [bat](https://github.com/sharkdp/bat) with syntax highlighting in the
current Catppuccin flavour, `cd` learns your habits through
[zoxide](https://github.com/ajeetdsouza/zoxide), and `git diff` is paged
through [delta](https://github.com/dandavison/delta) side by side.

`fd` and `ripgrep` come along because the rest of nekoshell uses them: the fzf
plugin walks files with `fd`, and `rg` is what searches a repository fast.

## Installs

`eza`, `bat`, `fd`, `ripgrep`, `zoxide`, `git-delta` (Homebrew formulas).

## Files

Symlinked into your home:

- `~/.config/bat/config` — bat's defaults
- `~/.config/bat/themes/Catppuccin *.tmTheme` — the four flavours
- `~/.config/nekoshell/git/delta.gitconfig` — delta's git settings

Appended to `~/.gitconfig`, once, inside a `# nekoshell:modern-cli` region:
an `[include]` pointing at that delta config. The rest of your `~/.gitconfig`
is never rewritten.

## After install

Nothing. Open a new shell and `ls`, `cat`, `z` and `git diff` are the new ones.

## Remove

`nekoshell plugin remove modern-cli` unlinks the configs and takes the include
region back out of `~/.gitconfig`. Add `purge` to uninstall the formulas too,
as long as no other enabled plugin needs them.
