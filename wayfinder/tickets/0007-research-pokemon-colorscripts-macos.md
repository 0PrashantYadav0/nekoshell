---
id: 0007
title: Research: install path for pokemon-colorscripts and fastfetch image logos on macOS
type: wayfinder:research
status: closed
assignee: claude (2026-09-11)
blocked_by: []
---

## Question

pokemon-colorscripts and krabby have no Homebrew formula (checked 2026-09-11). Find the cleanest unattended install (git clone + install.sh vs pipx vs cargo), how PokéFetch pairs it with fastfetch, and the fastfetch JSONC config for `logo.type: iterm` with a PNG on iTerm2 3.7, including the known issue where `auto` fails to show the image in iTerm.

## Resolution

Resolved 2026-09-11 from the pokemon-colorscripts README (GitLab) and the fastfetch logo wiki.

- pokemon-colorscripts: Python 3 script + unicode/ANSI text sprites, MIT licensed, ~900 Pokémon gen 1 to 8. README credits The Pokémon Company (trademarks) and PokéSprite (box art). Keep it as a dependency, never copy sprites into nekoshell.
- Upstream install: `git clone https://gitlab.com/phoneybadger/pokemon-colorscripts.git && cd pokemon-colorscripts && sudo ./install.sh`. nekoshell installer will clone into `~/.local/share/pokemon-colorscripts` (pinned commit) and symlink `pokemon-colorscripts` into `~/.local/bin`, so no sudo.
- Flags: `-r` random (optional generation filter `-r 1-3`), `-rn a,b,c`, `--no-title`, `-s` shiny, `-b` big, `-n name`, `-f form`, `-l` list.
- fastfetch: `--file-raw -` reads a pre-rendered logo from stdin, so the greeting is `pokemon-colorscripts -r --no-title | fastfetch --file-raw -` (same pattern the wiki shows for pokeget). PokéFetch instead writes to `~/.cache/pokemon.txt` and passes `--logo`. For images: `--logo-type iterm --logo path.png` with both `--logo-width` and `--logo-height` set; known to work in iTerm2. Issue 2246 says `auto` may not show the image in iTerm, so always set the type explicitly. Paths in config may use `~`.
- Shiny odds: the script has `-s`; nekoshell does its own 1/128 roll and passes `-s`.
