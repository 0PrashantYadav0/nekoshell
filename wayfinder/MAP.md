---
label: wayfinder:map
title: nekoshell route map
created: 2026-09-11
---

## Destination

An approved spec for **nekoshell** (working name): an open-source, reproducible iTerm2 + zsh setup for macOS that (1) looks deliberately designed, (2) greets each new terminal with a Pokémon or anime image plus live machine stats, (3) opens a Spotify side panel on one hotkey, and (4) can be installed end to end by a human following the docs or by an AI agent handed the repo. The map is done when nothing is left to decide before the repo can be built.

## Notes

- Domain: macOS 26.5 on Apple M1 with 8 GB RAM. iTerm2 3.7.0, zsh 5.9, Homebrew 6.0.22, oh-my-zsh + Powerlevel10k currently installed, MesloLGS NF is the only Nerd Font present, Spotify desktop app installed, GitHub account `0PrashantYadav0` authenticated in `gh`.
- Every session consults: `grilling` and `domain-modeling` for HITL tickets, `research` for AFK research tickets, `prototype` for mockups. `CONTEXT.md` at the repo root is the glossary.
- Standing preferences: keep iTerm2 (do not switch terminals), keep zsh, stay lightweight (8 GB machine), Homebrew is the package source, docs must be written so an AI agent can run the install unattended.
- Execution mode (from 2026-09-11): the user approved building. Plan: `docs/superpowers/plans/2026-09-11-nekoshell-v0.1.md`, executed with subagent-driven development on branch `build/v0.1`. Tickets 0011 and 0012 are folded into that plan.
- Pitch artifact for the human: see the "Nekoshell Plan" artifact published 2026-09-11.

## Decisions so far

<!-- one line per closed ticket: [title](tickets/NNNN-slug.md): gist -->

- [Name the project, pick the license, confirm the GitHub owner](tickets/0001-name-license-owner.md): nekoshell, `0PrashantYadav0/nekoshell`, MIT.
- [Choose the colour theme and the Nerd Font](tickets/0002-theme-and-font.md): Catppuccin Mocha, JetBrainsMono Nerd Font 15 pt.
- [Decide the zsh prompt and plugin stack](tickets/0003-prompt-and-shell-stack.md): Starship + antidote; oh-my-zsh and p10k retired, aliases migrated.
- [Define the greeting](tickets/0004-greeting-behaviour.md): 70/30 Pokémon vs own art pack, no live fetch, no bundled copyrighted images, guarded, 150 ms ceiling.
- [Define the Spotify panel](tickets/0005-spotify-panel.md): user has Premium; spotify_player in an iTerm2 hotkey window docked right, ⌥M, 30 percent width.
- [Decide the install mechanism and what the 'cloud guide' means](tickets/0009-install-mechanism-and-cloud-guide.md): stow + Brewfile + install.sh; both REMOTE.md and AGENTS.md.
- [Fix the platform scope for v1](tickets/0010-platform-scope.md): macOS + iTerm2 only; Linux stays in the fog.
- [Research: iTerm2 dynamic profile keys for a hotkey window docked right](tickets/0006-research-iterm2-profile-json.md): full key list captured; `Window Type` 6/10 still to confirm in the prototype.
- [Research: install path for pokemon-colorscripts and fastfetch image logos on macOS](tickets/0007-research-pokemon-colorscripts-macos.md): git clone into ~/.local, no sudo; greeting is one pipe into `fastfetch --file-raw -`; images via `--logo-type iterm`.
- [Research: controlling Spotify from the terminal on a free account](tickets/0008-research-spotify-free-tier.md): spotify_player streams itself (Premium); shpotify is the AppleScript fallback for free users.
- [Task: create the GitHub repo and push the skeleton](tickets/0013-create-github-repo.md): https://github.com/0PrashantYadav0/nekoshell, created by the user; planning docs are the first commit.

## Not yet specified

- CI: whether a macOS GitHub Actions runner should dry-run `install.sh` on every PR, and how to test iTerm2 profile JSON without a GUI.
- Uninstall and rollback: how far to go (restore backed-up dotfiles only, or also remove Homebrew packages).
- Screenshot and GIF pipeline for the README (manual captures vs a scripted `vhs` tape).
- Depth of the tmux/zellij story: whether a multiplexer ships at all, or only as the non-iTerm2 fallback for the Spotify panel.
- The free-tier Spotify fallback UI: how much of a mini-TUI to build around AppleScript control if the user has no Premium.
- Light/dark theme switching at runtime (follow macOS appearance vs fixed dark).
- The exact list of extra CLI tools (yazi, atuin, lazygit, btop) and which get themed.
- Linux/Ghostty/Kitty port: which parts carry over once macOS v1 is done.

## Out of scope

- Replacing iTerm2 with another terminal emulator. User wants to change how iTerm2 looks, not leave it.
- Windows and WSL.
- Shells other than zsh (fish, bash, nushell).
- Playing Spotify audio inside the terminal without the desktop app on a free account. Spotify's API does not allow it.
