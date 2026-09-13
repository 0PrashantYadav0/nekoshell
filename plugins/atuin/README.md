# atuin

## What it does

Replaces Ctrl-R with [atuin](https://github.com/atuinsh/atuin): a real,
searchable shell history in a SQLite database, with the working directory, exit
code and duration of every command kept alongside it.

The up arrow is left alone — it still walks this session's history, which is
what it is for.

Nothing leaves the machine. Sync and the update check are both off in the
shipped config, so there is no account and no network call.

## Installs

`atuin` (Homebrew formula).

## Files

Symlinked into your home:

- `~/.config/atuin/config.toml` — offline, compact, fuzzy search, this
  session's commands filtered first

The history database itself lives in `~/.local/share/atuin` and is yours; it is
never touched by enabling or removing this plugin.

## After install

Nothing. Open a new shell and press Ctrl-R.

## Remove

`nekoshell plugin remove atuin` unlinks the config and leaves the history
database in place. Add `--purge` to uninstall the formula too, as long as no
other enabled plugin needs it.
