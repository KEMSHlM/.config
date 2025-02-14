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
  {
    "timtro/glslView-nvim",
    ft = "glsl",
    opts = {
      viewer_path = "glslViewer",
      args = { "-l" },
    },
  },
}
