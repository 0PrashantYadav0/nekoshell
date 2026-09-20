# mise

## What you get

mise, the successor to asdf: one tool that installs and switches versions of node, python, go, ruby and a few hundred others. Activated in every shell, so the versions a project names in `.mise.toml` or `.tool-versions` are on PATH as soon as you enter its directory; completions cached the way the gh plugin caches them.

## Using it

| Command | What it does |
| --- | --- |
| `mise use -g node@lts` | install a version and record it in the global config |
| `mise use python@3.13` | the same for the current project (writes `.mise.toml` there) |
| `mise ls` | what is installed |
| `nekoshell doctor --plugin mise` | is mise there, is the global config there |

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.config/mise/config.toml` | copied once, empty; one of your own is left alone | yes |
| `~/.cache/nekoshell/mise-completion.zsh` | written by the shell when missing or older than the mise binary | no |
| `~/.local/share/mise/` | mise's own: the installed tools | no |

## Theme

None.

## Turning it off

`nekoshell plugin remove mise` stops activating it in new shells; the config and the installed tools stay. `--purge` also uninstalls mise.
