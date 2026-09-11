---
id: 0006
title: Research: iTerm2 dynamic profile keys for a hotkey window docked right
type: wayfinder:research
status: closed
assignee: claude (2026-09-11)
blocked_by: []
---

## Question

Find the exact JSON keys in an iTerm2 Dynamic Profile that set: dedicated hotkey window on, window style 'Right of screen', the hotkey combo, animation, auto-hide, colours and font, and whether these keys are honoured from DynamicProfiles without touching the GUI. Also confirm whether iTerm2 3.7 needs 'Load preferences from a custom folder' for global key bindings.

## Resolution

Resolved 2026-09-11 from iTerm2 source (`sources/Settings/Profiles/ITAddressBookMgr.h`) and the hotkey/window docs.

Profile keys (all honoured from a DynamicProfiles JSON, no GUI needed):

```json
"Has Hotkey": true,
"HotKey Key Code": 46,
"HotKey Characters": "µ",
"HotKey Characters Ignoring Modifiers": "m",
"HotKey Modifier Flags": 524288,
"HotKey Window Animates": true,
"HotKey Window AutoHides": true,
"HotKey Window Floats": true,
"HotKey Window Reopens On Activation": false,
"HotKey Window Dock Click Action": 0,
"Window Type": 6,
"Space": -1,
"Screen": -2,
"Columns": 60,
"Custom Command": "Yes",
"Command": "/opt/homebrew/bin/spotify_player",
"Transparency": 0.08, "Blur": true, "Blur Radius": 20,
"Normal Font": "JetBrainsMonoNF-Regular 15"
```

Notes: modifier flag 524288 is NSEventModifierFlagOption (1<<19); key code 46 is M. Window styles per docs: "Right of screen" (stuck to the edge, uses Columns) vs "Full-height right of screen" (edge to edge). The numeric `Window Type` for the right-edge styles is believed to be 6 (full height) and 10 (partial) from the `iTermWindowType` enum, but this could not be confirmed online (the header moved and the Python API does not expose it). **Verify in ticket 0011** by creating the profile once in the GUI and reading `defaults read com.googlecode.iterm2 "New Bookmarks"`. Floating needs Space = all spaces. Global "Load preferences from a custom folder" is not required for hotkey windows; only the main profile key bindings might want it.
