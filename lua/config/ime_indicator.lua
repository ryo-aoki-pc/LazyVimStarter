-- IME の入力モード (あ / A) を、カーソルのそばに表示する。表示は 2 つある。
--  1. 状態が変わった瞬間に、カーソルのすぐそばへ短時間だけ出す (挿入・置換・端末モードと、検索の / ?)
--  2. 検索 (/ ?) の間は、検索欄の右端にずっと出しておく
--
-- なぜ必要か:
--  - lualine の あ / A は画面の最下段にあり、文字を打っている間の視線 (カーソル) から遠い。
--    <C-j> や Super+Space で切り替えた直後に「このまま打ってよいか」を、カーソルから目を離さずに
--    確かめたい (macOS や Windows の IME がカーソルの近くに出すモード表示と同じ発想)。
--  - 前回日本語のまま抜けたバッファでは、挿入モードや検索に入るだけで日本語に戻る (ime.lua の sticky)。
--    何も押さずに切り替わるので、その場で気付けるようにしたい。
--  - 検索している間は lualine そのものが見えない。noice が ext_messages を使うと Neovim が 'cmdheight' を
--    0 にする (ui.c の ui_refresh) ので、グローバルステータスラインが画面の最下段に来て、同じ最下段に
--    noice が描く検索欄 (LazyVim の bottom_search) に覆われる。そのため 2 で lualine の代わりをする。
--  - カーソル色 (ime.lua の IMECursor) でも状態は分かるが、tmux 越しでは既定で効かない。
--
-- 1 を出す場面: ime.lua の observe() から呼ばれる。observe() は状態が実際に変わったときだけ通るので、
-- 「変わった瞬間」だけを拾える。そのうえで挿入・置換・端末モードと、検索のコマンドラインのときだけ出す。
--  - 挿入・置換・端末モードでは、カーソルのすぐ下 (窓の最下行なら上) に出す。
--  - 検索では、noice が描く検索欄のカーソルの 1 行上に出す。relative = "cursor" の基準はバッファ側の
--    カーソルで検索欄とは無関係なので、noice の窓に合わせて置く (lua/config/noice_cmdline.lua)。
--  - <Esc> での英数化は、観測した時点でノーマルモードに移っているので出ない。
--  - : など検索以外のコマンドラインでは出さない (noice の : の欄は画面の上の方にあり、lualine が見えている)。
--  - 端末や GUI のフォーカスが外れている間も出さない。ibus の engine は全体で 1 つなので、
--    他のアプリ (や別の nvim) での切り替えも watcher 経由で届き、見ていない nvim に出てしまう。
--    フォーカスの通知が来ない環境 (tmux の focus-events が off など) では常に出すだけになる。
-- 1 が消える条件: DURATION_MS が経つか、次の入力 (カーソル移動・検索欄の変化)・モードの変化・ウィンドウの
-- 移動の早い方。浮動ウィンドウは開いた時点の位置に固定されて付いてこないので、打ち進めたら消す。
-- 2 は検索のコマンドラインに入ってから抜けるまで出し、状態が変わるたびに observe() から書き換える。
-- noice が無ければ、1 も 2 も検索では出さない (検索欄が無く、lualine が隠れることもない)。

local cmdline = require("config.noice_cmdline")

local M = {}

-- 1 を表示しておく時間 (ms)。
local DURATION_MS = 1000

-- 1 は、補完メニューが開いたまま切り替えても隠れないよう、blink.cmp のメニュー・ドキュメント・
-- シグネチャ (いずれも zindex 1001) より上に出す。短時間なので上に被っても実害はない。
local ZINDEX = 1100

-- 2 は検索欄 (noice の既定で 50) と、同じ右下に出る noice の mini (メッセージや LSP の進捗、60) より上、
-- 検索の補完メニュー (1001) より下に出す。検索欄の方が高ければ、その 1 つ上にする。
local BADGE_ZINDEX = 100

-- 2 を出すとき、noice が検索欄を描き終えるのを待つ間隔 (ms) と回数。
local BADGE_RETRY_MS = 15
local BADGE_TRIES = 20

local buf = nil ---@type integer|nil 1 で使い回すスクラッチバッファ
local win = nil ---@type integer|nil 1 の表示中の浮動ウィンドウ (表示していなければ nil)
local cmdline_win = nil ---@type integer|nil 1 を検索欄に出しているときの、その noice の窓

local badge_buf = nil ---@type integer|nil 2 で使い回すスクラッチバッファ
local badge = nil ---@type { win: integer, anchor: integer }|nil 2 の浮動ウィンドウと、それを置いた noice の窓

-- 1 の通し番号。前の表示のタイマーが、後から出した表示を消さないようにする。
local shown = 0

-- 端末や GUI にフォーカスがあるか (FocusLost / FocusGained で追う。理由は冒頭)。
local focused = true

-- 検索のコマンドライン (/ ?) か。
local function is_search()
  local cmdtype = vim.fn.getcmdtype()
  return cmdtype == "/" or cmdtype == "?"
end

-- あ / A の色。1 と 2 で揃える。
local function winhl(ja)
  return "NormalFloat:" .. (ja and "ImeIndicatorJa" or "ImeIndicatorAscii")
end

-- 1: 切り替えた瞬間の表示 -----------------------------------------------------

---@param redraw? boolean 検索欄に出していた場合に、消した結果をすぐ画面へ出す
---  (コマンドラインの入力中は画面が自動では描き直されないため。タイマーやフォーカスで消すとき)
function M.close(redraw)
  if win and vim.api.nvim_win_is_valid(win) and not pcall(vim.api.nvim_win_close, win, true) then
    -- 閉じられない場面ではハンドルを捨てずに残し、次の契機 (入力・モード変化など) で閉じ直す。
    -- 捨てると誰も閉じなくなり、画面に残り続ける。
    return
  end
  win = nil
  local anchor = cmdline_win
  cmdline_win = nil
  if redraw and anchor then
    -- 同じ検索欄がまだ開いていれば、カーソルを検索欄に置いたまま描き直す。
    local _, cwin, row, col = cmdline.cursor()
    if cwin == anchor then
      cmdline.redraw(cwin, row, col)
    end
  end
end

---@return boolean opened 出したか (検索欄に出したときは画面にも出してある)
local function popup(text, ja)
  -- 前の表示を閉じられなかったときは出さない (重ねて開くと古い方が残る)。
  if win or not focused or text == "" then
    return false
  end
  -- 文字を打つモードだけ。ノーマルモード (<C-o> 中の niI を含む)・ビジュアル・検索以外の
  -- コマンドラインでは出さない。検索では noice の検索欄の窓とカーソル位置 (0 始まり) を控える。
  local mode = vim.api.nvim_get_mode().mode
  local cwin, row, col
  if mode:match("^c") then
    if not is_search() then
      return false
    end
    cwin, row, col = select(2, cmdline.cursor())
    if not cwin then
      return false
    end
  elseif not mode:match("^[iRt]") then
    return false
  end
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    buf = vim.api.nvim_create_buf(false, true)
  end
  local line = " " .. text .. " "
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
  local config = {
    width = vim.api.nvim_strwidth(line),
    height = 1,
    style = "minimal",
    -- 'winborder' (0.11 以降) を設定しても枠は付けない (枠の分だけ周りの行を余計に隠すため)。
    border = "none",
    focusable = false,
    -- WinNew などを起こさない (autocmds.lua の全角スペースの matchadd などを走らせない)。
    noautocmd = true,
    zindex = ZINDEX,
  }
  if cwin then
    -- 検索欄のカーソルの 1 行上に出す。bufpos の文字の左上に窓の左下 (SW) を合わせる。
    -- 上に行が無い配置なら、文字の下に左上 (NW) を合わせる。
    local above = vim.fn.screenpos(cwin, row + 1, 1).row > 1
    config.relative = "win"
    config.win = cwin
    config.bufpos = { row, col }
    config.anchor = above and "SW" or "NW"
    config.row = above and 0 or 1
    config.col = 0
  else
    -- relative = "cursor" は開いた瞬間のカレントウィンドウのカーソル位置 (w_wrow / w_wcol) を使う。
    -- 0.11 の nvim_open_win はその位置を検証せずに読むが、winline() が内部で validate_cursor() を
    -- 呼ぶので、先に呼んでおけば位置も確定する。
    -- カーソルが窓の最下行にあると、すぐ下はステータスライン (か下の窓) になるので上に出す。
    local below = vim.fn.winline() < vim.fn.winheight(0)
    config.relative = "cursor"
    config.row = below and 1 or -1
    config.col = 0
  end
  win = vim.api.nvim_open_win(buf, false, config)
  cmdline_win = cwin
  shown = shown + 1
  local n = shown
  vim.defer_fn(function()
    if shown == n then
      M.close(true)
    end
  end, DURATION_MS)
  -- 浮動ウィンドウは開いた時点のカレントウィンドウのオプションを引き継ぐ (snacks の窓の
  -- winhighlight や winblend が移ってくる) ので、見た目に関わるものは上書きする。
  vim.wo[win].winhighlight = winhl(ja)
  vim.wo[win].winblend = 0
  if cwin then
    -- コマンドラインの入力中は画面が自動では描き直されないので、開いた窓を自分で画面に出す。
    -- 2 の書き換えも、ここでまとめて画面に出る。
    cmdline.redraw(cwin, row, col)
  end
  return true
end

-- 2: 検索欄の常時表示 ---------------------------------------------------------

local function badge_close()
  if badge and vim.api.nvim_win_is_valid(badge.win) and not pcall(vim.api.nvim_win_close, badge.win, true) then
    return -- 1 の close() と同じく、閉じられなければ次の契機で閉じ直す
  end
  badge = nil
end

-- 検索中なら、検索欄の右端の表示を text / ja にする (無ければ開く)。検索中でなければ閉じる。
-- 画面には出さないので、呼んだ側が cmdline.redraw() する。
---@return integer|nil cwin, integer|nil row, integer|nil col 書き換えたときの noice の窓とカーソル位置
local function badge_render(text, ja)
  if text == "" or not is_search() then
    badge_close()
    return nil
  end
  local _, cwin, row, col = cmdline.cursor()
  if not cwin then
    return nil -- noice がまだ検索欄を描いていない
  end
  if badge and (badge.anchor ~= cwin or not vim.api.nvim_win_is_valid(badge.win)) then
    badge_close()
  end
  if not (badge_buf and vim.api.nvim_buf_is_valid(badge_buf)) then
    badge_buf = vim.api.nvim_create_buf(false, true)
  end
  local line = " " .. text .. " "
  vim.api.nvim_buf_set_lines(badge_buf, 0, -1, false, { line })
  local width = vim.api.nvim_strwidth(line)
  -- 検索欄の 1 行目の右端に置く。検索欄の窓に対する位置なので、検索欄が動けば一緒に動く。
  local config = {
    relative = "win",
    win = cwin,
    row = 0,
    col = math.max(vim.api.nvim_win_get_width(cwin) - width, 0),
    width = width,
    height = 1,
  }
  if badge then
    vim.api.nvim_win_set_config(badge.win, config)
  else
    config.style = "minimal"
    config.border = "none"
    config.focusable = false
    config.noautocmd = true
    config.zindex = math.max(BADGE_ZINDEX, (vim.api.nvim_win_get_config(cwin).zindex or 0) + 1)
    badge = { win = vim.api.nvim_open_win(badge_buf, false, config), anchor = cwin }
    vim.wo[badge.win].winblend = 0
  end
  vim.wo[badge.win].winhighlight = winhl(ja)
  return cwin, row, col
end

-- 検索のコマンドラインに入った (か、入れ子のコマンドラインから戻った) ときに 2 を出す。noice は検索欄を
-- コマンドラインに入った後で描くので、窓ができるまで少し待つ。* # のようにマッピングが一気に打ち切る
-- 検索は、待つ間に抜けているので出さない。
local function badge_open()
  local tries = 0
  local function try()
    -- noice を無効にしている環境では検索欄が無いので待たない。
    if not is_search() or not package.loaded["noice"] then
      return
    end
    local ime = require("config.ime")
    local text = ime.status()
    local cwin, row, col = badge_render(text, ime.is_ja())
    if cwin then
      cmdline.redraw(cwin, row, col)
    elseif text ~= "" and tries < BADGE_TRIES then
      tries = tries + 1
      vim.defer_fn(try, BADGE_RETRY_MS)
    end
  end
  vim.schedule(try)
end

-- 公開: ime.lua の observe() から、状態が変わるたびに呼ばれる -------------------

---@param text string 表示する入力モード (ime.lua の status() の "あ" / "A"。"" なら出さない)
---@param ja boolean 日本語入力か (色を変える)
function M.show(text, ja)
  M.close()
  local cwin, row, col = badge_render(text, ja)
  -- 1 を出さない場面 (: の中など) で 2 だけが変わったときは、ここで画面に出す。
  if not popup(text, ja) and cwin then
    cmdline.redraw(cwin, row, col)
  end
end

-- ハイライトは colorscheme の切り替え (:hi clear) で消えるので ColorScheme で張り直す。
-- default = true なので、colorscheme 側が定義していればそちらを使う。
local function set_hl()
  -- 日本語はカーソル色 (ime.lua の IMECursor) と同じ橙にして、色の意味を揃える。
  vim.api.nvim_set_hl(0, "ImeIndicatorJa", { fg = "#1a1b26", bg = "#ff9e64", bold = true, default = true })
  -- 英数は tokyonight の青。橙と一目で見分けられればよい。
  vim.api.nvim_set_hl(0, "ImeIndicatorAscii", { fg = "#1a1b26", bg = "#7aa2f7", bold = true, default = true })
end

function M.setup()
  set_hl()
  local group = vim.api.nvim_create_augroup("user_ime_indicator", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_hl })
  -- 1 を早めに消す契機。表示している間だけ張るのではなく常設する: CursorMovedI は「前回発火した
  -- 位置」から動いたかで判定され、その位置は CursorMovedI の autocmd があるときしか更新されない。
  -- 表示のたびに張ると古い位置と比べられ、表示した直後に発火して消えることがある。
  -- 表示していなければ close() は何もしないので、常設しても負担はない。
  -- CmdlineChanged は検索欄での CursorMovedI に当たる。消した結果は続く noice の再描画で画面に出るので、
  -- ここでは描かない (lua/config/ime_preedit.lua の CmdlineChanged と同じ)。
  vim.api.nvim_create_autocmd({ "ModeChanged", "CursorMovedI", "CmdlineChanged", "WinLeave" }, {
    group = group,
    callback = function()
      M.close()
    end,
  })
  -- 2 はコマンドラインの出入りのたびに閉じ、検索のコマンドラインにいれば出し直す (入れ子のコマンドライン
  -- (検索中の <C-r>= など) では noice の欄が入れ替わるため)。閉じた結果は、続くコマンドラインの描画か
  -- コマンドラインを抜けた後の再描画で画面に出る。
  vim.api.nvim_create_autocmd({ "CmdlineEnter", "CmdlineLeave" }, {
    group = group,
    callback = function()
      badge_close()
      badge_open()
    end,
  })
  vim.api.nvim_create_autocmd("FocusLost", {
    group = group,
    callback = function()
      focused = false
      M.close(true)
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
