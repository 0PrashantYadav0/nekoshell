# fzf

## What you get

fzf's three zsh key bindings, each with a preview: files with bat, directories with an eza tree, history as the command itself. Tab completion goes through fzf-tab, which the core loads, and `cd` completions preview the directory with eza.

## Using it

| Key | Lists | Preview |
| --- | --- | --- |
| `Ctrl-T` | files under the current directory, pasted onto the command line | `bat`, first 200 lines, right 60 % |
| `Alt-C` | directories; picking one changes into it | `eza --tree --level=2`, right 60 % |
| `Ctrl-R` | shell history | the command, wrapped, three lines below the list |
| `Tab` after `cd` | completions through fzf-tab | `eza -1` of the directory |

With the atuin plugin enabled, atuin takes `Ctrl-R` (its `late.zsh` binds after this plugin), so the history preview only shows on a machine without atuin.

With `fd` on the path, which the modern-cli plugin installs, `FZF_DEFAULT_COMMAND` is `fd --type f --hidden --follow --exclude .git`, so `Ctrl-T` and a bare `fzf` honour `.gitignore`. Without `fd`, fzf's own walk stands.

## Files

Nothing in your home. The bindings come from `fzf --zsh`; the previews are `plugins/fzf/fzf.zsh`, sourced right after, as `FZF_CTRL_T_OPTS`, `FZF_ALT_C_OPTS` and `FZF_CTRL_R_OPTS`. To change one, export your own value in `~/.config/nekoshell/zsh/local.zsh`, which the zshrc sources last.

## Theme

The finder's colours come from `FZF_DEFAULT_OPTS`, exported by `~/.config/nekoshell/theme.zsh`, which `nekoshell theme` renders; fzf-tab is told to use the same options (`use-fzf-default-opts`). The bat preview follows `BAT_THEME` from the same file. Nothing in this plugin carries a colour.

## Turning it off

`nekoshell plugin remove fzf`; the next shell has no bindings (atuin's `Ctrl-R` stays if that plugin is enabled). `--purge` also uninstalls the `fzf` formula unless another enabled plugin needs it. The doctor's only row is `tool: fzf`.
