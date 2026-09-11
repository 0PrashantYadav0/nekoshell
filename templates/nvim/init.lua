-- nekoshell Neovim config. Yours to edit; nekoshell never overwrites it.
-- The leader has to be set before any mapping is made, so it goes first.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("nekoshell.options")
require("nekoshell.keymaps")

-- lazy.nvim bootstrap. Cloned on first start, into Neovim's own data directory
-- rather than into the nekoshell checkout, and pinned to the stable branch.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup(require("nekoshell.plugins"), {
  install = { colorscheme = { "catppuccin" } },
  checker = { enabled = false },
  change_detection = { notify = false },
})
