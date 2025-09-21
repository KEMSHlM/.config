-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local wk = require("which-key")

-- my settings
wk.add({
  {
    mode = { "n" },
    { "n", "nzz", desc = "Next Search Result" },
    { "N", "Nzz", desc = "Previoue Search Result" },
    { "+", "<C-a>", desc = "Increment" },
    { "-", "<C-x>", desc = "Decrement" },
    { "<C-a>", "gg<S-v>G", desc = "Select All" },
    { "s", group = "Window" },
    { "ss", "<cmd>split<cr>", desc = "Split Horizontal Window" },
    { "sv", "<cmd>vsplit<cr>", desc = "Split Vertical Window" },
    { "sh", "<C-w>h", desc = "Move Window Left" },
    { "sk", "<C-w>k", desc = "Move Window Up" },
    { "sj", "<C-w>j", desc = "Move Window Down" },
    { "sl", "<C-w>l", desc = "Move Window Right" },
    { "<tab>", "<cmd>tabnext<cr>", desc = "Next Tab" },
    { "<s-tab>", "<cmd>tabprev<cr>", desc = "Privious Tab" },
    { "<C-w><left>", "<C-w><", desc = "Resize Window Left" },
    { "<C-w><right>", "<C-w>>", desc = "Resize Window Right" },
    { "<C-w><up>", "<C-w>+", desc = "Resize Window Up" },
    { "<C-w><down>", "<C-w>-", desc = "Resize Window Down" },
    {
      "<leader>j",
      function()
        vim.diagnostic.goto_next()
      end,
      desc = "Diagnotics",
    },
    {
      "<leader>t",
      function()
        require("scripts.screenshot").insertScreenshot()
      end,
      desc = "Take Screenshot",
      cond = function()
        return vim.bo.filetype == "markdown"
      end,
    },
    {
      "?",
      function()
        require("which-key").show("")
      end,
      desc = "Show Keys",
    },
  },
  {
    mode = { "x" },
    { "p", "_dP", desc = "Paste" },
  },
})
