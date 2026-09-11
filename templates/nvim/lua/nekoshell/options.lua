-- Editor options. Yours to edit; nekoshell never overwrites this file.
local opt = vim.opt

-- Gutter and cursor
opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 8

-- True colour, so the Catppuccin palette arrives unrounded
opt.termguicolors = true

-- Indentation: two spaces, no tabs
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

-- Searching: case-insensitive until you type a capital
opt.ignorecase = true
opt.smartcase = true

-- New splits open where you are looking
opt.splitright = true
opt.splitbelow = true

opt.undofile = true
opt.updatetime = 250
opt.clipboard = "unnamedplus"
opt.mouse = "a"
