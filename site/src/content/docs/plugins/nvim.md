# nvim

## What you get

Neovim as the editor: `vim` and `vi` run it and `EDITOR` is `nvim`, so git and anything else that asks for an editor opens it. The config is four small Lua files, copied into your home once and yours after that. lazy.nvim bootstraps itself on the first start and fetches Catppuccin, nvim-treesitter, telescope, lualine, gitsigns, which-key, oil, indent-blankline, nvim-autopairs, Comment.nvim and nvim-web-devicons, pinned to released versions; the first `nvim` takes a few seconds while that happens, and needs the network.

Options set: line numbers and relative numbers, a permanent sign column, cursor line, 8 lines of scroll-off, true colour, two-space indentation with no tabs, smart-case search, splits opening right and below, persistent undo, the system clipboard, the mouse, and a terminal title of `nvim: <file>` so a tmux status line can show what a pane is editing.

## Using it

Leader is Space.

| Key | Does |
| --- | --- |
| `Space e` | browse files with oil |
| `Space f f` | Telescope: find files |
| `Space f g` | Telescope: live grep |
| `Space f b` | Telescope: buffers |
| `Space f h` | Telescope: help tags |
| `Ctrl-h`, `Ctrl-j`, `Ctrl-k`, `Ctrl-l` | move between windows, the letters tmux uses for panes |
| `Esc` | clear the search highlight |
| `Space w` | write |
| `Space q` | quit |

All in normal mode. Treesitter parsers installed on the first run: lua, vim, vimdoc, bash, python, javascript, typescript, json, yaml, toml, markdown. which-key shows the rest of a chord after the leader.

## Files

All copied once, and yours:

| Path | Holds |
| --- | --- |
| `~/.config/nvim/init.lua` | the leader, the requires, the lazy.nvim bootstrap |
| `~/.config/nvim/lua/nekoshell/options.lua` | the options above |
| `~/.config/nvim/lua/nekoshell/keymaps.lua` | the keys above |
| `~/.config/nvim/lua/nekoshell/plugins.lua` | the lazy.nvim plugin spec |

If `~/.config/nvim/init.lua` or `~/.config/nvim/init.vim` already exists, nothing is copied and `plugin add` says so; the shipped files stay under `plugins/nvim/files/copy/` to take pieces from. lazy.nvim keeps its clones in Neovim's own data directory, not in the checkout.

## Theme

`plugins.lua` reads `NEKOSHELL_THEME`, exported by `~/.config/nekoshell/theme.zsh`, and hands it to Catppuccin as the flavour, mocha when the variable is empty. lualine's theme is `auto`, so it follows. The variable is read once at startup: a Neovim already open keeps the old flavour until it restarts, and it takes a new shell for the variable to change.

## Turning it off

`nekoshell plugin remove nvim` drops the two aliases and the plugin's `EDITOR` export; the core `env.zsh` still sets `EDITOR` to `nvim` while the binary is installed, and to `vim` otherwise. The config stays; delete `~/.config/nvim` yourself if you want it gone. `--purge` also uninstalls the `neovim` formula unless another enabled plugin needs it. The doctor's only row is `tool: nvim`.
