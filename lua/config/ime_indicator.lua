-- IME の状態が変わった瞬間に、カーソルのすぐ下へ入力モード (あ / A) を短時間だけ表示する。
--
-- なぜ必要か:
--  - lualine の あ / A は画面の最下段にあり、文字を打っている間の視線 (カーソル) から遠い。
--    <C-j> や Super+Space で切り替えた直後に「このまま打ってよいか」を、カーソルから目を離さずに
--    確かめたい (macOS や Windows の IME がカーソルの近くに出すモード表示と同じ発想)。
--  - 前回日本語のまま抜けたバッファでは、挿入モードに入るだけで日本語に戻る (ime.lua の sticky)。
--    何も押さずに切り替わるので、その場で気付けるようにしたい。
--  - 挿入モードのカーソル色 (ime.lua の IMECursor) でも状態は分かるが、tmux 越しでは既定で効かない。
--
-- 出す場面: ime.lua の observe() から呼ばれる。observe() は状態が実際に変わったときだけ通るので、
-- 「変わった瞬間」だけを拾える。そのうえで挿入・置換・端末モードのときだけ出す。
--  - <Esc> での英数化は、観測した時点でノーマルモードに移っているので出ない。
--  - コマンドライン (: /) では出さない。relative = "cursor" の基準はバッファ側のカーソルで、
--    noice が描くコマンドラインの窓とは位置が無関係なため (状態は lualine で見る)。
--  - 端末や GUI のフォーカスが外れている間も出さない。ibus の engine は全体で 1 つなので、
--    他のアプリ (や別の nvim) での切り替えも watcher 経由で届き、見ていない nvim に出てしまう。
--    フォーカスの通知が来ない環境 (tmux の focus-events が off など) では常に出すだけになる。
-- 消える条件: DURATION_MS が経つか、次の入力 (カーソル移動)・モードの変化・ウィンドウの移動の早い方。
-- 浮動ウィンドウは開いた時点のカーソル位置に固定されて付いてこないので、カーソルが動いたら消す。

local M = {}

-- 表示しておく時間 (ms)。
local DURATION_MS = 1000

-- 補完メニューが開いたまま切り替えても隠れないよう、blink.cmp のメニュー・ドキュメント・
-- シグネチャ (いずれも zindex 1001) より上に出す。短時間なので上に被っても実害はない。
local ZINDEX = 1100

local buf = nil ---@type integer|nil 使い回すスクラッチバッファ
local win = nil ---@type integer|nil 表示中の浮動ウィンドウ (表示していなければ nil)

-- 表示の通し番号。前の表示のタイマーが、後から出した表示を消さないようにする。
local shown = 0

-- 端末や GUI にフォーカスがあるか (FocusLost / FocusGained で追う。理由は冒頭)。
local focused = true

function M.close()
  if win and vim.api.nvim_win_is_valid(win) and not pcall(vim.api.nvim_win_close, win, true) then
    -- 閉じられない場面ではハンドルを捨てずに残し、次の契機 (入力・モード変化など) で閉じ直す。
    -- 捨てると誰も閉じなくなり、画面に残り続ける。
    return
  end
  win = nil
end

---@param text string 表示する入力モード (ime.lua の status() の "あ" / "A"。"" なら出さない)
---@param ja boolean 日本語入力か (色を変える)
function M.show(text, ja)
  M.close()
  -- 文字を打つモードだけ。ノーマルモード (<C-o> 中の niI を含む)・ビジュアル・コマンドラインでは出さない。
  -- 前の表示を閉じられなかったときも出さない (重ねて開くと古い方が残る)。
  if win or not focused or text == "" or not vim.api.nvim_get_mode().mode:match("^[iRt]") then
    return
  end
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    buf = vim.api.nvim_create_buf(false, true)
  end
  local line = " " .. text .. " "
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
  -- relative = "cursor" は開いた瞬間のカレントウィンドウのカーソル位置 (w_wrow / w_wcol) を使う。
  -- 0.11 の nvim_open_win はその位置を検証せずに読むが、winline() が内部で validate_cursor() を
  -- 呼ぶので、先に呼んでおけば位置も確定する。
  -- カーソルが窓の最下行にあると、すぐ下はステータスライン (か下の窓) になるので上に出す。
  local below = vim.fn.winline() < vim.fn.winheight(0)
  win = vim.api.nvim_open_win(buf, false, {
    relative = "cursor",
    row = below and 1 or -1,
    col = 0,
    width = vim.api.nvim_strwidth(line),
    height = 1,
    style = "minimal",
    -- 'winborder' (0.11 以降) を設定しても枠は付けない (枠の分だけ周りの行を余計に隠すため)。
    border = "none",
    focusable = false,
    -- WinNew などを起こさない (autocmds.lua の全角スペースの matchadd などを走らせない)。
    noautocmd = true,
    zindex = ZINDEX,
  })
  shown = shown + 1
  local n = shown
  vim.defer_fn(function()
    if shown == n then
      M.close()
    end
  end, DURATION_MS)
  -- 浮動ウィンドウは開いた時点のカレントウィンドウのオプションを引き継ぐ (snacks の窓の
  -- winhighlight や winblend が移ってくる) ので、見た目に関わるものは上書きする。
  vim.wo[win].winhighlight = "NormalFloat:" .. (ja and "ImeIndicatorJa" or "ImeIndicatorAscii")
  vim.wo[win].winblend = 0
end

-- ハイライトは colorscheme の切り替え (:hi clear) で消えるので ColorScheme で張り直す。
-- default = true なので、colorscheme 側が定義していればそちらを使う。
local function set_hl()
  -- 日本語は挿入モードのカーソル色 (ime.lua の IMECursor) と同じ橙にして、色の意味を揃える。
  vim.api.nvim_set_hl(0, "ImeIndicatorJa", { fg = "#1a1b26", bg = "#ff9e64", bold = true, default = true })
  -- 英数は tokyonight の青。橙と一目で見分けられればよい。
  vim.api.nvim_set_hl(0, "ImeIndicatorAscii", { fg = "#1a1b26", bg = "#7aa2f7", bold = true, default = true })
end

function M.setup()
  set_hl()
  local group = vim.api.nvim_create_augroup("user_ime_indicator", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_hl })
  -- 早めに消す契機。表示している間だけ張るのではなく常設する: CursorMovedI は「前回発火した
  -- 位置」から動いたかで判定され、その位置は CursorMovedI の autocmd があるときしか更新されない。
  -- 表示のたびに張ると古い位置と比べられ、表示した直後に発火して消えることがある。
  -- 表示していなければ close() は何もしないので、常設しても負担はない。
  vim.api.nvim_create_autocmd({ "ModeChanged", "CursorMovedI", "WinLeave" }, {
    group = group,
    callback = function()
      M.close()
    end,
  })
  vim.api.nvim_create_autocmd("FocusLost", {
    group = group,
    callback = function()
      focused = false
      M.close()
    end,
  })
  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    callback = function()
      focused = true
    end,
  })
end

return M
