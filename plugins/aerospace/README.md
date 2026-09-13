# aerospace

## What it does

Tiles macOS windows the way i3 tiles Linux ones, with
[AeroSpace](https://github.com/nikitabobko/AeroSpace): windows arrange
themselves instead of being dragged, `alt` plus a letter moves the focus,
`alt` plus a number moves you between workspaces, and nothing overlaps unless
you ask it to.

It sits beside tmux rather than replacing it: tmux tiles panes inside one
terminal window, AeroSpace tiles the windows themselves.

The shipped config leaves `alt-m` unbound — that is the Spotify panel's
hotkey — and floats the nekoshell panel window instead of tiling it.

## Installs

The `nikitabobko/tap` Homebrew tap and the `aerospace` cask.

## Files

Copied into your home, once, and yours from then on:

- `~/.config/aerospace/aerospace.toml`

If that file already exists, nothing is copied and the add says so; the
shipped one stays readable in the checkout under
`plugins/aerospace/files/copy`.

## After install

Open AeroSpace once and grant it Accessibility in System Settings → Privacy &
Security → Accessibility. Nothing tiles until you do, and no installer can
answer that dialog for you. `nekoshell doctor` warns until AeroSpace answers.

## Remove

`nekoshell plugin remove aerospace` drops it from the enabled list. Your
`aerospace.toml` stays where it is — it is yours — and the app keeps running
until you quit it. Add `purge` to uninstall the cask too.
