return {
  -- "navarasu/onedark.nvim",
  -- lazy = false,
  -- priority = 1000,
  -- config = function()
  --   require("onedark").setup({
  --     style = "warm",
  --     transparent = true,
  --   })
  --   require("onedark").load()
  -- end,{
  "catppuccin/nvim",
  lazy = true,
  name = "catppuccin",
  opts = function(_, opts)
    -- Temporary fix for bufferline integration
    local module = require("catppuccin.groups.integrations.bufferline")
    if module then
      module.get = module.get_theme
    end
    
    opts.transparent_background = true
    opts.integrations = {
      aerial = true,
      alpha = true,
      cmp = true,
      blink_cmp = true,
      dashboard = true,
      flash = true,
      fzf = true,
      grug_far = true,
      gitsigns = true,
      headlines = true,
      illuminate = true,
      indent_blankline = { enabled = true },
      leap = true,
      lsp_trouble = true,
      mason = true,
      markdown = true,
      mini = true,
      native_lsp = {
        enabled = true,
        underlines = {
          errors = { "undercurl" },
          hints = { "undercurl" },
          warnings = { "undercurl" },
          information = { "undercurl" },
        },
      },
      navic = { enabled = true, custom_bg = "lualine" },
      neotest = true,
      neotree = true,
      noice = true,
      notify = true,
      semantic_tokens = true,
      snacks = true,
      telescope = true,
      treesitter = true,
      treesitter_context = true,
      which_key = true,
    }
    
    return opts
  end,
  specs = {
    {
      "akinsho/bufferline.nvim",
      optional = true,
      opts = function(_, opts)
        if (vim.g.colors_name or ""):find("catppuccin") then
          local has_catppuccin, catppuccin_bufferline = pcall(require, "catppuccin.groups.integrations.bufferline")
          if has_catppuccin and catppuccin_bufferline.get_theme then
            opts.highlights = catppuccin_bufferline.get_theme()
          elseif has_catppuccin and catppuccin_bufferline.get then
            -- Fallback for older versions
            opts.highlights = catppuccin_bufferline.get()
          end
        end
      end,
    },
  },
}
