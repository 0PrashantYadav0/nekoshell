# spotify

## What it does

Puts Spotify in the terminal instead of a window of its own. `nekoshell
music` opens it here, or in your terminal's panel with `--panel`, and it is
the plugin `music_player = "auto"` finds, because it is tagged `media`.

Two ways in, picked automatically:

- [spotify_player](https://github.com/aome510/spotify-player) streams by
  itself, with a full terminal UI in the current Catppuccin flavour. It needs
  a Spotify Premium account.
- [shpotify](https://github.com/hnarayanan/shpotify) drives the Spotify
  desktop app instead — space for play/pause, `n`/`p` to skip, `+`/`-` for
  volume, `q` to quit. This is the fallback when spotify_player is missing,
  and `nekoshell-spotify --remote` asks for it directly.

`nekoshell spotify` looks after the login and your client id:

- `nekoshell spotify client-id <id>` puts your own Spotify client id in
  app.toml (see "After install" for why you want one).
- `nekoshell spotify login` forgets the cached login and runs
  `spotify_player authenticate` again.
- `nekoshell spotify logout` forgets the cached login and stops there.

## Installs

`spotify_player` and `shpotify` (Homebrew formulas).

## Files

- `~/.config/spotify-player/app.toml` — copied once, then yours. The device
  name, volume, bitrate and the playback window, and the place your
  `client_id` goes. `nekoshell plugin add spotify` never overwrites it; one
  that is already there from any other spotify_player setup is kept as it is.
  Two lines are edited in place and nothing else is touched: `theme` by
  `nekoshell theme`, `client_id` by `nekoshell spotify client-id`. A machine
  that installed the earlier version, where this file was a symlink into the
  checkout, gets a copy of its own the next time the plugin is added.
- `~/.config/spotify-player/theme.toml` — rendered, nekoshell's. The
  Catppuccin palette for the flavour in force, written on add and on every
  `nekoshell theme <flavour>`, under a header that names nekoshell. Edits to
  it are lost on the next switch; `files/theme.toml.tmpl` is the thing to
  edit.

## After install

1. Log in. Run `nekoshell music` (or `spotify_player authenticate`): a browser
   window opens for the Spotify authorisation, and the result is cached in
   `~/.cache/spotify-player/credentials.json`. `nekoshell doctor` warns until
   that file exists.

2. Get a client id of your own. Spotify's rate limit is per application, not
   per account, and the id spotify_player ships with (ncspot's,
   `d420a117a32841c2b3474932e49fb54b`) is shared by everyone who has not
   registered one. On it, the seven requests spotify_player makes at start-up
   all come back `429 Too Many Requests`, and the window sits empty for the
   12-14 seconds Spotify says to wait. An id of your own has a quota of its
   own, and it is free:

   1. Open <https://developer.spotify.com/dashboard> and log in with your
      Spotify account.
   2. Create an app. Name and description are yours to pick. Under "Redirect
      URIs" add exactly `http://127.0.0.1:8989/login` — spotify_player's
      default `login_redirect_uri`, which the copied app.toml pins — and
      choose "Web API" as what the app uses. Save.
   3. On the app's page, open Settings and copy its Client ID: 32 hex
      characters.
   4. `nekoshell spotify client-id <that id>`, then `nekoshell spotify login`
      to log in through it.

   `nekoshell doctor` warns with those commands until the id is set, and shows
   its first characters once it is. Endpoints a newly registered app is not
   allowed to use fall back to the shared id on their own.

## Remove

`nekoshell plugin remove spotify` removes the rendered theme.toml (only when
its header names nekoshell) and drops the plugin, so `nekoshell music` no
longer finds a player. app.toml stays: it is yours, and your client id is in
it. Add `--purge` to uninstall the formulas too, as long as no other enabled
plugin needs them. Your cached Spotify login is left alone; `nekoshell spotify
logout` (or deleting `~/.cache/spotify-player`) forgets it.
