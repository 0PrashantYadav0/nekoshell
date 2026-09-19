# modern-cli

## What you get

`ls` is eza with icons and directories first, `cat` is bat with syntax highlighting and no pager, `z` jumps to a directory zoxide has learned, and `git diff`, `git log` and `git show` are paged through delta with line numbers. `fd` and `rg` (ripgrep) are installed alongside and not aliased; the fzf plugin walks files with `fd` when it is present.

Man pages open through bat as well. That comes from the core `env.zsh`, which sets `MANPAGER` whenever `bat` is on the path.

## Using it

Every alias is guarded: when the tool is missing the alias is not defined and the original command stays.

| Alias | Runs |
| --- | --- |
| `ls` | `eza --icons --group-directories-first` |
| `ll` | `eza --icons --group-directories-first -l --git` |
| `la` | `eza --icons --group-directories-first -la --git` |
| `lt` | `eza --icons --tree --level=2` |
| `cat` | `bat --paging=never` |
| `z DIR` | zoxide's jump, defined by `zoxide init zsh` |

delta is git's `core.pager` and `interactive.diffFilter`, with `navigate` on (so `n` and `N` move between files inside a diff), `line-numbers` on, `side-by-side` off, and `merge.conflictstyle = zdiff3`.

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.config/bat/config` | linked | edits change the repository copy; it holds `--style=numbers,changes,header` |
| `~/.config/bat/themes/Catppuccin {Latte,Frappe,Macchiato,Mocha}.tmTheme` | linked | no |
| `~/.config/nekoshell/git/delta.gitconfig` | linked | edits change the repository copy |
| `~/.gitconfig` | an `[include]` of the delta config is appended once, between `# nekoshell:modern-cli begin` and `# nekoshell:modern-cli end` | yes; that region is the only part nekoshell touches |

## Theme

bat's theme is not in its config: `~/.config/nekoshell/theme.zsh`, rendered by `nekoshell theme`, exports `BAT_THEME="Catppuccin <Flavour>"`, and delta names no `syntax-theme`, so it falls back to the same variable. The plugin's theme hook runs `bat cache --build` on every switch so bat sees the four linked themes. `nekoshell doctor` has one row per tool and a `bat theme` row that warns with `bat cache --build` when the cache is stale.

## Turning it off

`nekoshell plugin remove modern-cli` unlinks the configs and themes and removes the include region from `~/.gitconfig`; the aliases are gone in the next shell. `--purge` also uninstalls eza, bat, fd, ripgrep, zoxide and git-delta unless another enabled plugin lists them.
