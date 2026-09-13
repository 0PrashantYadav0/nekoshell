# nvim

## What it does

Sets up [Neovim](https://neovim.io) as the editor: `vim` and `vi` both reach
it, `EDITOR` points at it, and it opens in the same Catppuccin flavour as the
rest of the shell — the colourscheme reads `NEKOSHELL_THEME`, so a
`nekoshell theme latte` reaches the editor the next time you open it.

The config is small on purpose: [lazy.nvim](https://github.com/folke/lazy.nvim)
bootstraps itself, treesitter, telescope and a statusline come with it, and
everything else is left for you to add.

It also asks Neovim to keep the terminal title current (`nvim: <file>`), which
is how a tmux statusbar knows a pane is editing something rather than sitting
at a prompt.

## Installs

`neovim` (Homebrew formula). Plugins are fetched by lazy.nvim the first time
you open the editor, not by this plugin.

## Files

Copied into your home, once, and yours from then on:

- `~/.config/nvim/init.lua`
- `~/.config/nvim/lua/nekoshell/options.lua`
- `~/.config/nvim/lua/nekoshell/keymaps.lua`
- `~/.config/nvim/lua/nekoshell/plugins.lua`

If `~/.config/nvim/init.lua` or `~/.config/nvim/init.vim` already exists,
nothing is copied at all and the add says so: your Neovim stays yours whole.
The files are still readable in the checkout under `plugins/nvim/files/copy`
if you want to take pieces of them by hand.

## After install

Open `nvim` once and let lazy.nvim fetch the plugins; it takes a few seconds
and only happens on the first run.

## Remove

`nekoshell plugin remove nvim` stops the aliases and the `EDITOR` export. The
copied config stays where it is — it is yours — so delete `~/.config/nvim`
yourself if you want it gone. Add `purge` to uninstall the formula too, as
long as no other enabled plugin needs it.
