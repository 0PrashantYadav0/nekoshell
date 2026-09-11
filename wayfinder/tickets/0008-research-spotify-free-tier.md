---
id: 0008
title: Research: controlling Spotify from the terminal on a free account
type: wayfinder:research
status: closed
assignee: claude (2026-09-11)
blocked_by: []
---

## Question

Confirm what shpotify (Homebrew 2.1) can do against the desktop app with a free account (play/pause, next, search, volume), whether spotify_player can act as a remote for the desktop app without Premium, and what spotify_player needs as a Spotify Connect device (librespot backend, audio device selection) on macOS.

## Resolution

Resolved 2026-09-11 from the spotify_player README, docs/config.md, THEMES.md and the shpotify README. The user has Premium (ticket 0005), so this fallback is for other users of the repo.

- spotify_player 0.25.1 (Homebrew) streams by itself via librespot with the `rodio` backend and registers a Spotify Connect device named `spotify-player` (configurable under `[device]`: name, volume, bitrate 320). Premium is required for playback. Auth is OAuth PKCE: first run opens the browser and captures the redirect on `http://127.0.0.1:8989/login`; `spotify_player authenticate` does it up front. No developer app needed (optional custom `client_id` to avoid the shared rate limit). Config in `~/.config/spotify-player/app.toml` + `theme.toml`; select with `theme = "..."` or `-t`; Catppuccin is a community theme collection, vendor Mocha into theme.toml. `enable_media_control` is off by default on macOS; leave it off. `playback_window_position = "Top"` and `playback_window_height` fit a narrow panel.
- Free tier: shpotify (Homebrew 2.1) drives the desktop app through AppleScript: play/pause/next/prev/replay/pos/stop, vol up/down/<n>, status. Searching by name needs a Spotify developer client id and secret in `~/.shpotify.cfg`. Doctor detects the tier by trying `spotify_player playback` after login; on failure it points the panel profile at the shpotify wrapper.
