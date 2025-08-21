return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    version = false, -- set this if you want to always pull the latest change
    opts = {
      provider = "claude",
      auto_suggestions_provider = "copilot",
      behaviour = {
        auto_suggestions = false,
        auto_set_highlight_group = true,
        auto_set_keymaps = true,
        auto_apply_diff_after_generation = true,
        support_paste_from_clipboard = true,
      },
      -- レート制限対策の追加設定
      request_delay = 1000, -- リクエスト間に1秒の遅延
      max_concurrent_requests = 1, -- 同時リクエスト数を1に制限
      windows = {
        position = "smart",
        width = 30,
        sidebar_header = {
          enabled = true,
          align = "center",
          rounded = true,
        },
        ask = {
          floating = true,
          start_insert = false,
          border = "rounded",
        },
        edit = {
          start_insert = false,
          border = "rounded",
        },
      },
      providers = {
        claude = {
          endpoint = "https://api.anthropic.com",
          model = "claude-3-7-sonnet-20250219", -- $3/$15, maxtokens=64000
          -- model = "claude-sonnet-4-20250514", -- $3/$15, maxtokens=64000
          -- model = "claude-opus-4-20250514", -- $15/$75, maxtokens=32000
          extra_request_body = {
            max_tokens = 4096, -- レート制限対策で削減
            temperature = 0,
          },
          -- レート制限対策の設定を追加
          timeout = 60000, -- 60秒のタイムアウト
          max_retries = 3,
          retry_delay = 2000, -- 2秒の遅延
        },
        openai = {
          endpoint = "https://api.openai.com/v1",
          model = "gpt-4o",
          extra_request_body = {
            max_tokens = 4096, -- レート制限対策で削減
          },
          timeout = 60000,
          max_retries = 3,
          retry_delay = 2000,
        },
      },
      system_prompt = function()
        local hub = require("mcphub").get_hub_instance()
        return hub and hub:get_active_servers_prompt() or ""
      end,
      -- Using function prevents requiring mcphub before it's loaded
      custom_tools = function()
        return {
          require("mcphub.extensions.avante").mcp_tool(),
        }
      end,
    },
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = "make",
    -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      --- The below dependencies are optional,
      "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
      "zbirenbaum/copilot.lua", -- for providers='copilot'
      {
        -- support for image pasting
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          -- recommended settings
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
          },
        },
      },
      {
        -- Make sure to set this up properly if you have lazy=true
        "MeanderingProgrammer/render-markdown.nvim",
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
  },
}
