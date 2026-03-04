-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Restore <C-j> / <C-k> inside Claude Code terminal so they act as newline/up
vim.api.nvim_create_autocmd("TermOpen", {
  pattern = "*",
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    -- Defer to let the buffer name be set by the terminal provider
    vim.defer_fn(function()
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      local name = vim.api.nvim_buf_get_name(buf)
      if name:match("claude") then
        pcall(vim.keymap.del, "t", "<C-j>", { buffer = buf })
        pcall(vim.keymap.del, "t", "<C-k>", { buffer = buf })
      end
    end, 100)
  end,
})

-- Turn off paste mode when leaving insert
vim.api.nvim_create_autocmd("InsertLeave", {
  pattern = "*",
  command = "set nopaste",
})

-- Fix conceallevel for json files
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "json", "jsonc" },
  callback = function()
    vim.wo.spell = false
    vim.wo.conceallevel = 0
  end,
})

-- Prevent opening binary/media files that can cause nvim to freeze
vim.api.nvim_create_autocmd({ "BufReadPre" }, {
  pattern = "*",
  callback = function()
    local binary_extensions = {
      -- Video files
      "mp4",
      "avi",
      "mov",
      "mkv",
      "flv",
      "wmv",
      "webm",
      "m4v",
      "mpg",
      "mpeg",
      -- Audio files
      "mp3",
      "wav",
      "flac",
      "aac",
      "ogg",
      "m4a",
      "wma",
      -- Image files (large)
      "png",
      "jpg",
      "jpeg",
      "gif",
      "bmp",
      "tiff",
      "ico",
      "webp",
      -- Archive files
      "zip",
      "rar",
      "7z",
      "tar",
      "gz",
      "bz2",
      "xz",
      -- Other binary files
      "pdf",
      "exe",
      "dll",
      "so",
      "dylib",
      "bin",
      "iso",
    }

    local filename = vim.fn.expand("<afile>")
    local ext = vim.fn.fnamemodify(filename, ":e"):lower()

    if vim.tbl_contains(binary_extensions, ext) then
      vim.schedule(function()
        vim.notify(
          string.format("Refusing to open binary file: %s\nUse appropriate viewer instead.", filename),
          vim.log.levels.WARN
        )
        vim.api.nvim_buf_delete(0, { force = true })
      end)
      return
    end
  end,
})
