---
id: 0005
title: Define the Spotify panel: account tier, hotkey, and panel behaviour
type: wayfinder:grilling
status: closed
assignee: claude (2026-09-11)
blocked_by: []
---

## Question

Does the user have Spotify Premium? spotify_player needs Premium for playback control; free accounts get a fallback that drives the Spotify desktop app through AppleScript (shpotify). Which global hotkey toggles the panel (recommend ⌥M, alternative ⌃⌥S)? Panel: iTerm2 dedicated hotkey window, style 'Right of screen', width about 30 percent, animates in, toggles on the same key.

## Resolution

Decided by the user on 2026-09-11: the user **has Spotify Premium**, so **spotify_player** is the panel client. Hotkey **⌥M**, iTerm2 dedicated hotkey window, style Right of screen, 30 percent width, animated, toggles on the same key. The AppleScript remote for free accounts remains as the documented fallback for other users of the repo (see ticket 0008).
