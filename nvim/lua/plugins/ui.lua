return {
  -- messages, cmdline and the popupmenu
  {
    "folke/noice.nvim",
    opts = function(_, opts)
      table.insert(opts.routes, {
        filter = {
          event = "notify",
          find = "No information available",
        },
        opts = { skip = true },
      })
      local focused = true
      vim.api.nvim_create_autocmd("FocusGained", {
        callback = function()
          focused = true
        end,
      })
      vim.api.nvim_create_autocmd("FocusLost", {
        callback = function()
          focused = false
        end,
      })
      table.insert(opts.routes, 1, {
        filter = {
          cond = function()
            return not focused
          end,
        },
        view = "notify_send",
        opts = { stop = false },
      })

      opts.commands = {
        all = {
          -- options for the message history that you get with `:Noice`
          view = "split",
          opts = { enter = true, format = "details" },
          filter = {},
        },
      }

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function(event)
          vim.schedule(function()
            require("noice.text.markdown").keys(event.buf)
          end)
        end,
      })

      opts.presets.lsp_doc_border = true
    end,
  },

  {
    "rcarriga/nvim-notify",
    keys = {
      {
        "<leader>un",
        function()
          require("notify").dismiss({ silent = true, pending = true })
        end,
        desc = "Dismiss all Notifications",
      },
    },
    opts = {
      timeout = 3000,
      background_colour = "#0000FF",
      max_height = function()
        return math.floor(vim.o.lines * 0.75)
      end,
      max_width = function()
        return math.floor(vim.o.columns * 0.75)
      end,
      on_open = function(win)
        vim.api.nvim_win_set_config(win, { zindex = 100 })
      end,
    },
  },

  -- buffer line
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    keys = {
      { "<Tab>", "<Cmd>BufferLineCycleNext<CR>", desc = "Next tab" },
      { "<S-Tab>", "<Cmd>BufferLineCyclePrev<CR>", desc = "Prev tab" },
    },
    opts = {
      options = {
        mode = "tabs",
        -- separator_style = "slant",
        show_buffer_close_icons = false,
        show_close_icon = false,
      },
    },
  },

  -- statusline
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function()
      local colors = {
        blue = "#80a0ff",
        cyan = "#79dac8",
        black = "#080808",
        white = "#c6c6c6",
        red = "#ff5189",
        violet = "#d183e8",
        grey = "#303030",
      }

      local bubbles_theme = {
        normal = {
          a = { fg = colors.black, bg = colors.violet },
          b = { fg = colors.white, bg = colors.grey },
          c = { fg = colors.white },
        },
        insert = { a = { fg = colors.black, bg = colors.blue } },
        visual = { a = { fg = colors.black, bg = colors.cyan } },
        replace = { a = { fg = colors.black, bg = colors.red } },
        inactive = {
          a = { fg = colors.white, bg = colors.black },
          b = { fg = colors.white, bg = colors.black },
          c = { fg = colors.white },
        },
      }

      return {
        options = {
          theme = bubbles_theme,
          component_separators = "",
          section_separators = { left = "", right = "" },
          disabled_filetypes = {
            statusline = {},
            winbar = {},
          },
        },
        sections = {
          lualine_a = { { "mode", separator = { left = "" }, right_padding = 2 } },
          lualine_b = { "filename", "branch" },
          lualine_c = {
            "'%='",
            {
              "diff",
              symbols = { added = " ", modified = " ", removed = " " },
              separator = nil,
            },
            {
              "diagnostics",
              symbols = { error = " ", warn = " ", info = " ", hint = " " },
            },
          },
          lualine_x = {},
          lualine_y = { "filetype", "progress" },
          lualine_z = {
            { "location", separator = { right = "" }, left_padding = 2 },
          },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = {},
          lualine_x = {},
          lualine_y = { "filename" },
          lualine_z = { "location" },
        },
        tabline = {},
        extensions = { "quickfix", "neo-tree" },
      }
    end,
  },

  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    opts = {
      plugins = {
        gitsigns = true,
        tmux = true,
        kitty = { enabled = false, font = "+2" },
      },
    },
    keys = { { "<leader>z", "<cmd>ZenMode<cr>", desc = "Zen Mode" } },
  },

  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = [[
          ▓█████▄ ▓█████  ██▓███   ██▓     ██▓ ▄████▄   ▄▄▄     ▄▄▄█████▓▓█████ ▓█████▄ 
          ▒██▀ ██▌▓█   ▀ ▓██░  ██▒▓██▒    ▓██▒▒██▀ ▀█  ▒████▄   ▓  ██▒ ▓▒▓█   ▀ ▒██▀ ██▌
          ░██   █▌▒███   ▓██░ ██▓▒▒██░    ▒██▒▒▓█    ▄ ▒██  ▀█▄ ▒ ▓██░ ▒░▒███   ░██   █▌
          ░▓█▄   ▌▒▓█  ▄ ▒██▄█▓▒ ▒▒██░    ░██░▒▓▓▄ ▄██▒░██▄▄▄▄██░ ▓██▓ ░ ▒▓█  ▄ ░▓█▄   ▌
          ░▒████▓ ░▒████▒▒██▒ ░  ░░██████▒░██░▒ ▓███▀ ░ ▓█   ▓██▒ ▒██▒ ░ ░▒████▒░▒████▓ 
          ▒▒▓  ▒ ░░ ▒░ ░▒▓▒░ ░  ░░ ▒░▓  ░░▓  ░ ░▒ ▒  ░ ▒▒   ▓▒█░ ▒ ░░   ░░ ▒░ ░ ▒▒▓  ▒ 
          ░ ▒  ▒  ░ ░  ░░▒ ░     ░ ░ ▒  ░ ▒ ░  ░  ▒     ▒   ▒▒ ░   ░     ░ ░  ░ ░ ▒  ▒ 
          ░ ░  ░    ░   ░░         ░ ░    ▒ ░░          ░   ▒    ░         ░    ░ ░  ░ 
            ░       ░  ░             ░  ░ ░  ░ ░            ░  ░           ░  ░   ░    
          ░                                  ░                                  ░      
          ]],
        },
      },
    },
  },
}
