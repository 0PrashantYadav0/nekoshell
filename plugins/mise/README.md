# mise

## What it does

Installs [mise](https://mise.jdx.dev), the successor to asdf: one tool that
installs and switches versions of node, python, go, ruby and a few hundred
others, per project or globally. The plugin activates it in every shell, so
the versions a project's `.mise.toml` or `.tool-versions` names are on PATH
the moment you `cd` into it, and caches its completions under
`~/.cache/nekoshell/` so a new shell does not wait for them.

## Installs

`mise` (Homebrew formula).

## Files

Copied into your home, once, and yours from then on:

- `~/.config/mise/config.toml` — the global tool versions; empty to begin
  with. One already there is left alone.

## After install

`mise use -g node@lts` (or any tool) puts a version in the global config;
`mise ls` shows what is installed. Nothing else.

## Remove

`nekoshell plugin remove mise` stops activating it; your `config.toml` and
the tools mise installed under `~/.local/share/mise` stay. `--purge`
uninstalls mise itself.
