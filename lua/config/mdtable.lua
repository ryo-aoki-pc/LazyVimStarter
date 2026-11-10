-- mdtable の編集コマンドとの配線。Excel のブックの管理と書き戻しは mdtable に任せる。
local M = {}

function M.edit()
  local buf = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(buf)
  if filename == "" then
    vim.notify("mdtable: ファイルを保存してから使ってください。", vim.log.levels.ERROR)
    return
  end

  local executable = vim.fn.exepath("mdtable")
  if executable == "" then
    vim.notify(
      "mdtable が見つかりません。md-table-excel の docs/install.md の"
        .. "「Windows 11 で mdtable を導入・更新する」に従って導入してください: "
        .. "https://github.com/ryo-aoki-pc/md-table-excel/blob/main/docs/install.md"
        .. "#windows-11-で-mdtable-を導入更新する",
      vim.log.levels.ERROR
    )
    return
  end

  -- mdtable はファイルを読むため、未保存の変更を先に書き出す。
  if vim.bo[buf].modified then
    local ok, err = pcall(vim.cmd.write)
    if not ok then
      vim.notify("mdtable: 保存に失敗しました: " .. tostring(err), vim.log.levels.ERROR)
      return
    end
  end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  -- 配列は shell を通さず渡す。空白や日本語を含むパスを PowerShell の引用に任せない。
  -- Snacks.terminal の既定に任せ、終了コード 0 なら閉じて checktime、失敗時は端末を残す。
  Snacks.terminal({ executable, "edit", vim.fn.fnamemodify(filename, ":p"), "--table", "L" .. line })
end

return M
