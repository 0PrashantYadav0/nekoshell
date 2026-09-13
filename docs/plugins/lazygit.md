# lazygit

## What you get

lazygit, a keyboard-driven terminal UI for git, opened with `lg`: stage hunks, amend, rebase, cherry-pick and read the log without leaving the keyboard. Diffs inside it are paged through delta, so they read the same way `git diff` does with the modern-cli plugin.

## Using it

`lg` is `lazygit`; run it inside a repository. Everything inside is lazygit's own key map; the plugin adds no bindings. The linked config sets `nerdFontsVersion: "3"` for the icons and `git.paging.pager` to `delta --dark --paging=never` with `colorArg: always`. delta comes from the modern-cli plugin; this plugin does not install it.

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.config/lazygit/config.yml` | linked | edits change the repository copy |

## Theme

Fixed. The config carries Catppuccin Mocha hex colours for the borders, the selected line, cherry-picked commits, unstaged changes and the search border, and there is no theme hook, so `nekoshell theme` does not change them. Only the diff text follows the flavour, through delta, which reads `BAT_THEME` from `~/.config/nekoshell/theme.zsh`. The pager's `--dark` flag stays on under latte too.

## Turning it off

`nekoshell plugin remove lazygit` unlinks the config and drops the alias. `--purge` also uninstalls the formula unless another enabled plugin needs it. The doctor's only row is `tool: lazygit`.
