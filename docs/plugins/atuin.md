# atuin

## What you get

`Ctrl-R` opens atuin's history search: every command from every shell on this machine, with its directory, exit code and duration, fuzzy-matched in a compact list of 20 lines that opens under the prompt. The up arrow is left alone and still walks the current session's history.

Nothing leaves the machine: `auto_sync` and `update_check` are off, so there is no account and no network call.

## Using it

Press `Ctrl-R` and type. The plugin defines no aliases and no other keys; everything inside the search is atuin's own. Settings in the linked config:

| Setting | Value |
| --- | --- |
| `auto_sync` | `false` |
| `update_check` | `false` |
| `style` | `compact` |
| `inline_height` | `20` |
| `search_mode` | `fuzzy` |
| `filter_mode_shell_up_key_binding` | `session`; only matters if you bind the up arrow yourself |

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.config/atuin/config.toml` | linked | edits change the repository copy |
| `~/.local/share/atuin/` | atuin's own database | yours; never touched by add or remove |

atuin is started from the plugin's `late.zsh` with `atuin init zsh --disable-up-arrow`, after every plugin's `plugin.zsh`, so its `Ctrl-R` wins over fzf's whatever order the two were enabled in.

## Theme

None. The config sets no colours and the plugin has no theme hook; atuin draws with its defaults.

## Turning it off

`nekoshell plugin remove atuin` unlinks the config; the next shell's `Ctrl-R` goes back to fzf's history search (with the fzf plugin) or zsh's. The history database stays. `--purge` also uninstalls the formula unless another enabled plugin needs it. The doctor's only row is `tool: atuin`.
