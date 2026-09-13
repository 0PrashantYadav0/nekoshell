# p10k

## What it does

Replaces Starship with [Powerlevel10k](https://github.com/romkatv/powerlevel10k) as the prompt, using the lean two-line config that ships here: directory and git status on the first line, the prompt character on the second, and the last command's duration, the Python virtualenv, user@host and the clock on the right. The colours follow the Catppuccin flavour in force, so `nekoshell theme latte` recolours the prompt too. Starship stays installed and comes back the moment the plugin is removed.

Powerlevel10k's instant prompt is on when the greet plugin is not enabled. With the greeting, the two would fight for the top of the window, so instant prompt is off and the prompt arrives after the greeting.

## Installs

`powerlevel10k` (Homebrew formula).

## Files

- `~/.p10k.zsh` is copied once and is yours from then on. An existing `~/.p10k.zsh` is left alone, so a config you already have keeps working; delete it and add the plugin again to get ours. `p10k configure` rewrites it with Powerlevel10k's own wizard.
- `~/.config/nekoshell/p10k-colors.zsh` is rendered on every theme switch and sourced just before your config, whose colour lines read the `NEKOSHELL_P10K_*` values it exports.

## After install

Open a new shell. If you kept your own `~/.p10k.zsh` and use the greet plugin, set `POWERLEVEL9K_INSTANT_PROMPT=off` in it (or `quiet`) to silence the instant prompt warning.

## Remove

`nekoshell plugin remove p10k` drops the plugin and Starship takes the prompt back on the next shell. `~/.p10k.zsh` stays, since it is yours. Add `--purge` to uninstall the formula as well.
