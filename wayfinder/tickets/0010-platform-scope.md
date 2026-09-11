---
id: 0010
title: Fix the platform scope for v1
type: wayfinder:grilling
status: closed
assignee: claude (2026-09-11)
blocked_by: []
---

## Question

Is v1 macOS + iTerm2 only, with Linux terminals (Ghostty, Kitty, WezTerm) as a later effort? Recommendation: yes. The greeting, fonts and CLI theme carry over; the hotkey side panel is iTerm2-specific and would need a tmux fallback on Linux.

## Resolution

Decided by the user on 2026-09-11: **v1 is macOS + iTerm2 only**. Linux terminals (Ghostty, Kitty, WezTerm) stay in the fog for a later effort; the greeting, prompt and CLI theme are written to port, the hotkey panel is not.
