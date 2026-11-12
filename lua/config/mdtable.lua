-- mdtable の編集コマンドとの配線。Excel のブックの管理と書き戻しは mdtable に任せる。
local M = {}

local install_url = "https://github.com/ryo-aoki-pc/md-tools/blob/main/mdtable/docs/install.md"
  .. "#windows-11-で-mdtable-を導入更新する"

local function fail(message)
  vim.notify("mdtable: " .. message, vim.log.levels.ERROR)
end

function M.edit()
  local buf = vim.api.nvim_get_current_buf()
  -- :MdTableEdit はどのバッファからも呼べるので、Markdown のファイルのバッファだけを相手にする。
  if vim.bo[buf].buftype ~= "" or vim.bo[buf].filetype ~= "markdown" then
    fail("Markdown のファイルのバッファで使ってください。")
    return
  end

  local filename = vim.api.nvim_buf_get_name(buf)
  if filename == "" then
    fail("ファイルを保存してから使ってください。")
    return
  end

  -- 読み取り専用のバッファは、変更が無くても開かない (Excel で編集した後で、書き戻せないと分かるのを避ける)。
  if vim.bo[buf].readonly or not vim.bo[buf].modifiable then
    fail("読み取り専用のバッファでは使えません。")
    return
  end

  local executable = vim.fn.exepath("mdtable")
  if executable == "" then
    fail(
      "コマンドが見つかりません。md-tools の mdtable/docs/install.md の"
        .. "「Windows 11 で mdtable を導入・更新する」に従って導入してください: "
        .. install_url
    )
    return
  end

  if not (_G.Snacks and Snacks.terminal) then
    fail("snacks.nvim の端末 (Snacks.terminal) を使えません。")
    return
  end

  -- mdtable はファイルを読むため、未保存の変更を先に書き出す。
  if vim.bo[buf].modified then
    local ok, err = pcall(vim.cmd.write)
    if not ok then
      fail("保存に失敗しました: " .. tostring(err))
      return
    end
  end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  -- 配列は shell を通さず渡す。空白や日本語を含むパスを PowerShell の引用に任せない。
  -- Snacks.terminal の既定に任せ、終了コード 0 なら閉じて checktime、失敗時は端末を残す。
  Snacks.terminal({ executable, "edit", vim.fn.fnamemodify(filename, ":p"), "--table", "L" .. line })
end

return M
