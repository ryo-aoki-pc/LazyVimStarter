-- noice が描くコマンドライン (/ ? : など) の窓に、自分で描き足すための道具。
-- lua/config/ime_preedit.lua (Neovide の未確定文字列) と lua/config/ime_indicator.lua (検索中の あ / A) が使う。
--
-- noice は Neovim 本体のコマンドライン (バッファではない) の代わりに、浮動ウィンドウのバッファへ
-- コマンドラインを描いている。そこへ extmark や浮動ウィンドウを足すには、その窓とカーソルの位置が要る。
-- また、コマンドラインの入力中は Neovim が画面を自動では描き直さないので、足したものは自分で画面に出す。

local M = {}

-- noice が描いているコマンドラインの、カーソル位置のバッファ座標。描けないときは nil。
-- noice は読み込み済みのときだけ使う (無効にしている環境で require して読み込ませない)。
---@return integer|nil buf, integer|nil win, integer|nil row, integer|nil col (row / col は 0 始まり)
function M.cursor()
  local noice = package.loaded["noice"]
  if not noice or vim.fn.getcmdtype() == "" then
    return nil
  end
  local ok, pos = pcall(noice.api.get_cmdline_position)
  -- position はコマンドラインを閉じても残る (次に開くまで古い値) ので、ウィンドウの生存も確かめる。
  if not ok or not pos or not pos.buf or not pos.win then
    return nil
  end
  if not vim.api.nvim_buf_is_valid(pos.buf) or not vim.api.nvim_win_is_valid(pos.win) then
    return nil
  end
  -- noice は自分のカーソルを「バッファの最終行・pos.cursor バイト目」に置く (noice の fix_cursor)。
  return pos.buf, pos.win, vim.api.nvim_buf_line_count(pos.buf) - 1, pos.cursor
end

-- noice のコマンドラインのウィンドウを描き直し、カーソルを画面に出す。コマンドラインの入力中は
-- Neovim が通常のウィンドウを自動では描き直さない (noice もコマンドラインの内容が変わった時にしか
-- 描かない) ので自分で描く。noice は描くたびにウィンドウのカーソルを置いてから画面に出すが、
-- その後でウィンドウのカーソル自体は行頭に戻っていることがある (実測)。そのまま描き直すと
-- 画面のカーソルが行頭へ飛ぶので、noice と同じ位置 (noice の fix_cursor) に置き直してから描く。
-- flush は保留中の描画をすべて画面に出すので、直前に開け閉めした浮動ウィンドウもここで反映される。
---@param win integer noice のコマンドラインの窓 (cursor() の win)
---@param row integer cursor() の row
---@param col integer cursor() の col
function M.redraw(win, row, col)
  pcall(vim.api.nvim_win_set_cursor, win, { row + 1, col })
  pcall(vim.api.nvim__redraw, { win = win, cursor = true, flush = true })
end

return M
