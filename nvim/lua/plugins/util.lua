return {
  {
    "mgierada/lazydocker.nvim",
    dependencies = { "akinsho/toggleterm.nvim" },
    config = function()
      require("lazydocker").setup({})
    end,
    event = "BufRead", -- or any other event you might want to use.
    keys = {
      {
        "<leader>dd",
        function()
          require("lazydocker").open()
        end,
        desc = "Lazy docker",
      },
    },
  },
  {
    "kndndrj/nvim-dbee",
    dependencies = {
      "MunifTanjim/nui.nvim",
    },
    build = function()
      -- Install tries to automatically detect the install method.
      -- if it fails, try calling it with one of these parameters:
      --    "curl", "wget", "bitsadmin", "go"
      require("dbee").install()
    end,
    config = function()
      require("dbee").setup(--[[optional config]])
    end,
    keys = {
      {
        "<leader>db",
        function()
          require("dbee").open()
        end,
        desc = "Dbee",
      },
    },
  },
  --   {
  --     "jackMort/ChatGPT.nvim",
  --     event = "VeryLazy",
  --     config = function()
  --       local home = vim.fn.expand("$HOME")
  --       require("chatgpt").setup({
  --         api_key_cmd = "gpg --descrypt " .. home .. "/.api/chatgpt.api.gpg",
  --       })
  --     end,
  --     dependencies = {
  --       "MunifTanjim/nui.nvim",
  --       "nvim-lua/plenary.nvim",
  --       "folke/trouble.nvim",
  --       "nvim-telescope/telescope.nvim",
  --     },
  --     keys = {
  --       {
  --         "<leader>?e",
  --         "<cmd>ChatGPTEditWithInstruction<CR>",
  --         desc = "Edit with instruction",
  --       },
  --       {
  --         "<leader>?g",
  --         "<cmd>ChatGPTRun grammar_correct<CR>",
  --         desc = "Grammer correct",
  --       },
  --       {
  --         "<leader>?t",
  --         "<cmd>ChatGPTRun translate<CR>",
  --         desc = "Translate",
  --       },
  --       {
  --         "<leader>?s",
  --         "<cmd>ChatGPTRun summarize<CR>",
  --         desc = "Summarize",
  --       },
  --       {
  --         "<leader>?x",
  --         "<cmd>ChatGPTRun explain_code<CR>",
  --         desc = "Explain code",
  --       },
  --       {
  --         "<leader>?f",
  --         "<cmd>ChatGPTRun fix_bugs<CR>",
  --         desc = "Fix bugs",
  --       },
  --     },
  --   },
}
