# btop

## What it does

Adds [btop](https://github.com/aristocratos/btop), a resource monitor that is
worth looking at: CPU, memory, disks, network and processes, with history
graphs and a mouse that works. `top` opens it.

Its colours follow `nekoshell theme`: all four Catppuccin flavours are
installed, and a theme switch repoints btop at the matching one.

## Installs

`btop` (Homebrew formula).

## Files

Symlinked into your home:

- `~/.config/btop/themes/catppuccin_{frappe,latte,macchiato,mocha}.theme`

Touched, one line only:

- `~/.config/btop/btop.conf` — the `color_theme` line. btop owns and rewrites
  the rest of that file itself, so nothing else in it is ever changed.

## After install

Nothing. Open a new shell and type `top`.

## Remove

`nekoshell plugin remove btop` unlinks the themes and leaves `btop.conf`
alone — it is btop's file, not ours. Add `purge` to uninstall the formula too,
as long as no other enabled plugin needs it.
