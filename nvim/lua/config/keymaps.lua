-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local keymap = vim.keymap
local opts = { noremap = true, silent = true }

-- my settings
keymap.set("x", "p", '"_dP')
keymap.set("n", "n", "nzz")
keymap.set("n", "N", "Nzz")

-- Increment/decrement
keymap.set("n", "+", "<C-a>")
keymap.set("n", "-", "<C-x>")

-- Delete a word backwards
keymap.set("n", "dw", "vb_d")

-- Select all
keymap.set("n", "<C-a>", "gg<S-v>G")

-- Jumplist
keymap.set("n", "te", "tabedit", opts)
keymap.set("n", "<tab>", ":tabnext<Return>", opts)
keymap.set("n", "<s-tab>", ":tabprev<Return>", opts)

-- split window
keymap.set("n", "ss", ":split<Return>", opts)
keymap.set("n", "sv", ":vsplit<Return>", opts)

-- Move window
keymap.set("n", "sh", "<C-w>h")
keymap.set("n", "sk", "<C-w>k")
keymap.set("n", "sj", "<C-w>j")
keymap.set("n", "sl", "<C-w>l")

-- Resize window
keymap.set("n", "<C-w><left>", "<C-w><")
keymap.set("n", "<C-w><right>", "<C-w>>")
keymap.set("n", "<C-w><up>", "<C-w>+")
keymap.set("n", "<C-w><down>", "<C-w>-")

-- Diagnotics
keymap.set("n", "<leader>j", function()
  vim.diagnostic.goto_next()
end, opts)

-- Toggle inlay hints
keymap.set("n", "<leader>i", function()
  require("scripts.lsp").toggleInlayHints()
end)

-- setup screenshot
keymap.set("n", "<leader>t", function()
  require("scripts.screenshot").insertScreenshot()
end)

-- Show normal mode keymaps
keymap.set("n", "?", function()
  require("which-key").show("", { mode = "n", auto = true })
end)
