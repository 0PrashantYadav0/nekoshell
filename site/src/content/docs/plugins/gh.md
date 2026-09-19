# gh

## What you get

GitHub's command line with tab completion in every shell and delta as the pager for diffs. The completion script is generated once and cached, then regenerated only when gh itself is updated, so the shell does not pay for it on every start. Your own `gh` configuration (aliases, editor, git protocol) is left exactly as it is.

## Using it

| Command | What it does |
| --- | --- |
| `gh <Tab>` | completion for subcommands and flags |
| `gh pr diff` | the diff through delta, when modern-cli is enabled |
| `nekoshell doctor --plugin gh` | is gh there, is it logged in |

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.cache/nekoshell/gh-completion.zsh` | written by the shell when missing or older than the gh binary | no |
| `~/.config/gh/` | yours; the plugin never writes there | yes |

`GH_PAGER=delta` is exported when delta is on PATH.

## Theme

None of its own: gh draws in the terminal's palette, and delta follows the flavour through the modern-cli plugin.

## Turning it off

`nekoshell plugin remove gh` stops sourcing the completions and exporting the pager; `--purge` also uninstalls gh.
