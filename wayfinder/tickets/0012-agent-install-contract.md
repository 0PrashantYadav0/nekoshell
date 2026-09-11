---
id: 0012
title: Define the contract that lets an AI agent install nekoshell unattended
type: wayfinder:grilling
status: open
assignee:
blocked_by: [0009]
---

## Question

What must `AGENTS.md` and `docs/INSTALL.md` say so that 'tell your AI to install this' works? Recommend: exact commands in order, a `doctor` script whose output the agent must verify, explicit backup step for existing dotfiles, a list of the only prompts a human must answer (Spotify OAuth, macOS font cache), and a shipped skill folder so `npx skills add 0PrashantYadav0/nekoshell` works.
