---
id: 0009
title: Decide the install mechanism and what the 'cloud guide' means
type: wayfinder:grilling
status: closed
assignee: claude (2026-09-11)
blocked_by: []
---

## Question

How do dotfiles land on a machine: GNU stow (recommended, simple symlinks) or chezmoi (templates for Linux later)? Brewfile plus an idempotent `install.sh` with `--check` and `--dry-run`. Also: the request mentions a 'cloud guide'. Does that mean (a) installing on remote/cloud hosts over SSH, Codespaces and devcontainers, (b) a guide for Claude/AI agents, or (c) both? Recommend both: `docs/REMOTE.md` and `AGENTS.md`.

## Resolution

Decided by the user on 2026-09-11: **GNU stow** + **Brewfile** + idempotent `install.sh` with `--check` and `--dry-run`. 'Cloud guide' means **both**: `docs/REMOTE.md` (SSH hosts, Codespaces, devcontainers) and `AGENTS.md` (contract for AI agents). chezmoi only if a Linux port lands on the map.
