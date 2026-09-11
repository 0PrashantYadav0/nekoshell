---
id: 0004
title: Define the greeting: what shows, when, and where the art comes from
type: wayfinder:grilling
status: closed
assignee: claude (2026-09-11)
blocked_by: []
---

## Question

What appears when a terminal opens? Sub-questions: Pokémon vs anime mix (recommend 70/30, random per launch, shiny chance), which stats fastfetch shows, and where anime images come from. Licensing: Pokémon sprites and anime stills are copyrighted; recommend shipping pokemon-colorscripts as a dependency and shipping only CC0 sample images in `art/`, with a documented drop-your-own folder. Guards: only interactive top-level shells, skip inside tmux, skip when `CLAUDECODE` is set, skip over SSH unless opted in. Startup budget under 150 ms.

## Resolution

Decided by the user on 2026-09-11: random per launch, **70 percent Pokémon** via pokemon-colorscripts (with its shiny roll), **30 percent from the user's art pack** rendered with the iTerm2 inline image protocol. No live fetching from anime APIs. The repo ships only openly licensed sample images with attribution. Guards: interactive top-level shells only; skip in tmux, in the panel, when `CLAUDECODE` is set, and over SSH unless opted in. Startup ceiling 150 ms, measured by doctor.
