-- lazy.nvim plugin spec. Yours to edit; nekoshell never overwrites this file.
--
-- The colourscheme follows $NEKOSHELL_THEME, which ~/.config/nekoshell/theme.zsh
-- exports and `nekoshell theme <flavour>` rewrites, so one command moves the
-- editor with the rest of the rig. A Neovim already open keeps the old flavour
-- until it restarts, because the variable is read once at startup.
--
-- Versions are pinned so an upgrade is something you ask for. `version = "*"`
-- is lazy.nvim's "newest published release"; the two plugins that publish no
-- semver tags take their default branch instead, and nvim-treesitter takes
-- master, which is the branch that project maintains.
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    version = "^2.0.0",
    priority = 1000,
    lazy = false,
    config = function()
      local flavour = vim.env.NEKOSHELL_THEME
      if flavour == nil or flavour == "" then
        flavour = "mocha"
      end
      require("catppuccin").setup({
        flavour = flavour,
        integrations = {
          telescope = true,
          gitsigns = true,
          which_key = true,
          indent_blankline = { enabled = true },
        },
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    main = "nvim-treesitter.configs",
    opts = {
      ensure_installed = {
        "lua", "vim", "vimdoc", "bash", "python", "javascript",
        "typescript", "json", "yaml", "toml", "markdown",
      },
      highlight = { enable = true },
      indent = { enable = true },
    },
  },

  {
    "nvim-telescope/telescope.nvim",
    version = "*",
    dependencies = { { "nvim-lua/plenary.nvim", version = "*" } },
    opts = {},
  },

  {
    "nvim-lualine/lualine.nvim",
    -- No tagged releases, so this one tracks its default branch.
    version = false,
    opts = {
      -- "auto" derives the statusline colours from the colourscheme in force,
      -- which keeps lualine on the flavour without naming it twice.
      options = { theme = "auto", globalstatus = true },
    },
  },

  { "lewis6991/gitsigns.nvim", version = "*", opts = {} },
  { "folke/which-key.nvim", version = "*", event = "VeryLazy", opts = {} },
  { "stevearc/oil.nvim", version = "*", opts = {} },
  { "lukas-reineke/indent-blankline.nvim", version = "*", main = "ibl", opts = {} },
  { "windwp/nvim-autopairs", version = "*", event = "InsertEnter", opts = {} },
  { "numToStr/Comment.nvim", version = "*", opts = {} },
  -- Its tags are not semver, so lazy.nvim cannot resolve a version range here.
  { "nvim-tree/nvim-web-devicons", version = false, opts = {} },
}
