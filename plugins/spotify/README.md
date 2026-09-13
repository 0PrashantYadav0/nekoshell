# spotify

## What it does

Puts Spotify in a terminal panel instead of a window of its own.
`nekoshell music` opens it — through your terminal's panel or overlay if it
has one, in this window with `--here` — and it is the plugin `music_player =
"auto"` finds, because it is tagged `media`.

Two ways in, picked automatically:

- [spotify_player](https://github.com/aome510/spotify-player) streams by
  itself, with a full terminal UI in the current Catppuccin flavour. It needs
  a Spotify Premium account.
- [shpotify](https://github.com/hnarayanan/shpotify) drives the Spotify
  desktop app instead — space for play/pause, `n`/`p` to skip, `+`/`-` for
  volume, `q` to quit. This is the fallback when spotify_player is missing,
  and `nekoshell-spotify --remote` asks for it directly.

## Installs

`spotify_player` and `shpotify` (Homebrew formulas).

## Files

Symlinked into your home:

- `~/.config/spotify-player/app.toml` — the device name, volume and bitrate
- `~/.config/spotify-player/theme.toml` — the Catppuccin palette

## After install

Run `nekoshell music` once and log in: spotify_player opens a browser window
for the Spotify authorisation, and caches the result in
`~/.cache/spotify-player/credentials.json`. `spotify_player authenticate` does
the same thing directly. `nekoshell doctor` warns until that file exists.

## Remove

`nekoshell plugin remove spotify` unlinks the configs and drops the plugin, so
`nekoshell music` no longer finds a player. Add `--purge` to uninstall the
formulas too, as long as no other enabled plugin needs them. Your cached
Spotify credentials are left alone; delete `~/.cache/spotify-player` to log
out for good.
