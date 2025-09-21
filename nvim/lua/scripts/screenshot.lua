local M = {}

-- モジュールの初期設定関数
M.setup = function()
  -- Markdownファイルでのみコマンドを利用可能にする
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    callback = function()
      -- コマンドを登録
      vim.api.nvim_buf_create_user_command(0, "Screenshot", function()
        M.insertScreenshot()
      end, {
        desc = "Take and insert screenshot in markdown file",
      })
    end,
  })
end

-- カーソルの下にある単語を取得する関数
local function get_word_under_cursor()
  return vim.fn.expand("<cword>")
end

-- Markdownファイル内で次に使うべき画像の番号を決定する関数
local function get_next_img_number()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local highest_num = 0
  for _, line in ipairs(lines) do
    for num in string.gmatch(line, "%!%[img(%d+)%]") do
      num = tonumber(num)
      if num and num > highest_num then
        highest_num = num
      end
    end
  end
  return highest_num + 1
end

-- スクリーンショットを撮影してMarkdownファイルに挿入するメイン関数
M.insertScreenshot = function()
  -- Markdownファイルでない場合は実行しない
  if vim.bo.filetype ~= "markdown" then
    vim.notify("Error: This command can only be used in Markdown files", vim.log.levels.ERROR)
    return
  end
  -- スクリーンショットを保存するディレクトリのパスを組み立て
  local screenshotDir = vim.fn.expand("%:p:h") .. "/.img"
  -- スクリーンショットのファイル名
  local date_str = os.date("%Y%m%d_%H%M%S")
  local fileName = "screenshot_" .. date_str .. ".png"
  local filepath = screenshotDir .. "/" .. fileName
  -- カーソル下の単語を取得
  local cursorword = get_word_under_cursor()
  -- 次に使用する画像の番号を取得
  local img_num = get_next_img_number()
  -- 画像の参照名を取得（カーソル下の単語があればそれを使用、なければ連番）
  local description_name = cursorword ~= "" and cursorword or ("img" .. img_num)

  -- 保存先ディレクトリが存在しない場合は作成
  if vim.fn.isdirectory(screenshotDir) == 0 then
    local mkdir_result = vim.fn.mkdir(screenshotDir, "p")
    if mkdir_result == 0 then
      vim.notify("Error: Could not create the screenshot directory: " .. screenshotDir)
      return
    else
      vim.notify("Screenshot directory created: " .. screenshotDir)
    end
  end

  -- OSに応じたスクリーンショットコマンドを選択して実行
  local screenshotCmd = ""
  if vim.fn.has("mac") == 1 then
    screenshotCmd = "screencapture -i " .. vim.fn.shellescape(filepath)
  elseif vim.fn.has("unix") == 1 then
    screenshotCmd = "scrot -s " .. vim.fn.shellescape(filepath)
  else
    vim.notify("Error: Unsupported OS")
    return
  end

  -- スクリーンショットコマンドを実行
  if screenshotCmd ~= "" then
    local shellResult = vim.fn.system(screenshotCmd)
    if vim.v.shell_error ~= 0 then
      vim.notify("Error: Failed to take a screenshot." .. shellResult)
      return
    end
  end

  -- Markdownに画像リンクを挿入
  local relativeFilePath = string.format(".img/%s", fileName)
  local link_text = string.format('<img src="%s" alt="%s">', relativeFilePath, descriptionCame)
  vim.api.nvim_put({ link_text }, "l", true, true)
end

return M
