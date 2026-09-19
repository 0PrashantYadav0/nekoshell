# spotify

## What you get

Spotify in the terminal. `nekoshell music` (alias `music`) runs the player in the current window; `nekoshell music --panel` opens it in the terminal's panel instead: iTerm2's hotkey window, kitty's quick-access terminal, Ghostty's quick terminal, a popup inside tmux, or a new window in Warp and Terminal.app. It is the plugin `music_player = "auto"` finds, because it is tagged `media`.

Two players, picked by `nekoshell-spotify`, the plugin's launcher: spotify_player, a full terminal UI that streams on its own and needs Spotify Premium, when it is installed; otherwise a keyboard remote built on shpotify that drives the Spotify desktop app. `nekoshell-spotify --remote` asks for the remote directly.

The first spotify_player start opens a browser for the Spotify login and caches the result. spotify_player's built-in client id is shared with everyone who has not registered one and Spotify rate-limits it, so a start-up on it can sit empty for 12 to 14 seconds; `nekoshell spotify client-id` gives it an id of your own.

## Using it

| Command | Does |
| --- | --- |
| `nekoshell music`, `music` | run the player in this window |
| `nekoshell music --panel` | open it in the terminal's panel |
| `nekoshell music spotify` | name the player, when `music_player` in `nekoshell.toml` is something else |
| `nekoshell-spotify --remote` | the desktop-app remote, even with spotify_player installed |
| `nekoshell spotify search [QUERY]` (alias `sps`) | a search bar: fzf over the tracks, albums, artists and playlists Spotify finds for what you type, refilled as you type; Enter plays the pick on the active device (the player window or the desktop app must be running). Without fzf, a numbered menu. A search spotify_player cannot parse (`daft punk` is one) shows as one error line |
| `nekoshell spotify client-id ID` | write your Spotify app's client id (32 hex characters) into `app.toml` |
| `nekoshell spotify login` | forget the cached login and run `spotify_player authenticate`; do this after a new id |
| `nekoshell spotify logout` | forget the cached login; the next start asks again |

The remote's keys:

| Key | Does |
| --- | --- |
| `space` | play or pause |
| `n` | next |
| `p` | previous |
| `+`, `-` | volume up, down |
| `s` | status |
| `q` | quit |

Getting a client id: open <https://developer.spotify.com/dashboard>, create an app with the redirect URI `http://127.0.0.1:8989/login` and "Web API" ticked, copy its Client ID from the app's Settings, then run `nekoshell spotify client-id <id>` and `nekoshell spotify login`. The doctor's `spotify client id` row warns until this is done and shows the id's first characters once it is.

## Files

| Path | How | Edit it? |
| --- | --- | --- |
| `~/.config/spotify-player/app.toml` | copied once; one already there, from any spotify_player setup, is kept | yes. nekoshell rewrites two top-level lines and nothing else: `theme` on a theme switch, `client_id` on `nekoshell spotify client-id` |
| `~/.config/spotify-player/theme.toml` | rendered on add and on every theme switch | no; it is overwritten. A theme of your own goes in a file that app.toml's `theme` names |
| `~/.cache/spotify-player/credentials.json`, `*_token.json` | written by spotify_player on login | `nekoshell spotify logout` removes them |

The shipped `app.toml`: `theme = "catppuccin_mocha"`, media control and notifications off, the playback window at the top, 6 lines high, `client_port = 8080`, `login_redirect_uri = "http://127.0.0.1:8989/login"`, and under `[device]` the name `nekoshell`, volume 70, bitrate 320, with audio cache, normalization and autoplay off. Any other key spotify_player understands can be added.

A machine that ran the earlier version, where `app.toml` was a symlink into the checkout, gets a copy of its own the next time the plugin is added; a link that points elsewhere is left alone.

## Theme

`theme.toml` is rendered from `plugins/spotify/files/theme.toml.tmpl` as a theme named `catppuccin_<flavour>` with the flavour's palette, and the `theme` line in `app.toml` is pointed at that name when the line is there; a `theme` line you removed is not put back. The doctor's `spotify theme` row fails when the rendered file does not match the flavour in force.

Doctor rows: `tool: spotify_player`, `tool: shpotify (spotify)` (the formula is shpotify, the command it installs is `spotify`), `spotify login`, `spotify client id`, `spotify theme`.

## Turning it off

`nekoshell plugin remove spotify` removes the rendered `theme.toml` (only when its header names nekoshell) and drops the plugin, so `nekoshell music` finds no player. `app.toml` and the cached login stay; `nekoshell spotify logout` before removing forgets the login. `--purge` also uninstalls spotify_player and shpotify unless another enabled plugin needs them.
