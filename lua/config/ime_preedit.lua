-- Neovide で IME の未確定文字列 (preedit) をカーソル位置に表示する。
--
-- なぜ必要か:
--  - Neovide が使う winit は、Windows の WM_IME_COMPOSITION で DefWindowProc を呼ばず、
--    IME 自身による未確定文字列の描画を抑止している。代わりに未確定文字列を
--    neovide.preedit_handler() に渡してくるが、その既定実装は空関数なので、何もしないと
--    確定するまで 1 文字も画面に出ない (確定時の neovide.commit_handler() は既定で
--    nvim_input() するので、確定した文字だけが現れる)。
--  - 端末 (Windows Terminal / WezTerm) では未確定文字列を端末が自前で描き、Neovim には
--    確定した文字しか届かない。この仕組みは Neovide 専用で、それ以外では setup() が何もしない。
--  - preedit_handler が呼ばれるのは Neovide 0.16 以上 + Neovim 0.12 以上。それより古いと
--    差し替えても呼ばれないだけで無害。
--
-- 描き方: カーソル位置に inline の仮想テキスト (extmark) として置き、行の続きを右へ押し出す。
-- バッファ自体は確定まで一切変えないので、undo 履歴・TextChanged・LSP・補完は未確定文字列を見ない。

local M = {}

local ns = vim.api.nvim_create_namespace("user_ime_preedit")

---@type { buf: integer, id: integer }|nil 表示中の extmark (未確定文字列が無いときは nil)
local mark = nil

local function clear()
  if mark then
    pcall(vim.api.nvim_buf_del_extmark, mark.buf, ns, mark.id)
    mark = nil
  end
end

-- winit の Ime::Preedit が渡すカーソル範囲は「バイト単位・[s, e)・UTF-8 の文字境界」で、
-- s < e なら変換対象の文節、s == e なら変換前の入力位置を指す (nil はカーソル無し)。
-- 文節だけを別の見た目にし、それ以外 (変換前・範囲外・文字境界でない) は全体を同じ見た目にする。
local function chunks(text, s, e)
  local function boundary(i)
    return type(i) == "number" and i >= 0 and i <= #text and (i == #text or vim.str_utf_start(text, i + 1) == 0)
  end
  if not (boundary(s) and boundary(e) and s < e) then
    return { { text, "ImePreedit" } }
  end
  local out = {}
  for _, chunk in ipairs({
    { text:sub(1, s), "ImePreedit" },
    { text:sub(s + 1, e), "ImePreeditSelected" },
    { text:sub(e + 1), "ImePreedit" },
  }) do
    if chunk[1] ~= "" then
      table.insert(out, chunk)
    end
  end
  return out
end

local function render(text, s, e)
  -- 挿入・置換モード以外では描かない。コマンドラインはバッファの extmark では描けず、
  -- 端末モードは端末自身の描画と干渉するため対象外 (従来どおり確定まで見えない)。
  -- ノーマルモード (<C-o> 中の niI を含む) で未確定文字列を打つことはそもそも想定しない。
  if not vim.api.nvim_get_mode().mode:match("^[iR]") then
    clear()
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  if mark and mark.buf ~= buf then
    clear()
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local id = vim.api.nvim_buf_set_extmark(buf, ns, row - 1, col, {
    id = mark and mark.id or nil,
    virt_text = chunks(text, s, e),
    virt_text_pos = "inline",
    -- 左 gravity にするのが要。挿入モードのカーソルは、その位置にある「左 gravity の inline
    -- 仮想テキスト」の幅だけ右へずらして描かれる (右 gravity の分はノーマルモードでしか足されない。
    -- Neovim の plines.c の virt_text_cursor_off)。これでカーソルが未確定文字列の直後に来る。
    right_gravity = false,
  })
  mark = { buf = buf, id = id }
end

-- 未確定文字列が空になった (確定か取り消し) とき、消すまで待つ時間 (ms)。理由は on_preedit を参照。
local CLEAR_DELAY_MS = 30

-- Neovide から届いた preedit の通し番号と、最後に確定したときのその値。どちらも Neovide から
-- 呼ばれた瞬間 (= Neovide が送った順) に数える。main loop に回した描画は、確定文字列の入力より
-- 後に処理されることがある (入力キューが先に読まれる) ため、送られた順はここでしか分からない。
local received, committed = 0, 0

---@param n integer この preedit の通し番号
local function on_preedit(n, text, s, e)
  if text ~= "" then
    -- 確定より前に送られた未確定文字列は、確定文字列に追い越された古いもの。描くと確定文字列の
    -- 後ろに重なって見える (main loop が塞がっている間に「変換 → 確定」が届くと起きる)。
    if n > committed and not pcall(render, text, s, e) then
      clear()
    end
    return
  end
  -- 空 = 確定か取り消し。確定のとき winit は Preedit("") → Commit(text) と続けて出すが、Neovide は
  -- これを 1 往復ずつ順に Neovim へ渡すので、ここで即座に消すと確定文字列が届くまでの一瞬だけ
  -- 「未確定文字列も確定文字列も無い」画面が描かれ、Neovide のカーソルが左右に行き来する。
  -- 確定なら直後の挿入の直前に InsertCharPre で消える (setup 参照) ので、ここでは少し待ち、
  -- その間に次の未確定文字列も届かなかった (= 取り消し) ときだけ消す。
  vim.defer_fn(function()
    if received == n then
      clear()
    end
  end, CLEAR_DELAY_MS)
end

-- ハイライトは colorscheme の切り替え (:hi clear) で消えるので ColorScheme で張り直す。
-- default = true なので、colorscheme 側が定義していればそちらを使う。
local function set_hl()
  -- OS の IME と同じく下線で示す (背景色だと選択範囲と紛らわしい)。
  vim.api.nvim_set_hl(0, "ImePreedit", { underline = true, default = true })
  -- 変換対象の文節。配色に依存せず見分けられるよう反転させる。
  vim.api.nvim_set_hl(0, "ImePreeditSelected", { underline = true, reverse = true, default = true })
end

function M.setup()
  -- Neovide は nvim --embed の UI attach 前に g:neovide と Lua の neovide テーブルを用意するので、
  -- VeryLazy の時点では必ず揃っている。どちらかが無ければ Neovide ではない。
  if not vim.g.neovide or type(_G.neovide) ~= "table" then
    return
  end

  set_hl()
  local group = vim.api.nvim_create_augroup("user_ime_preedit", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_hl })

  -- 確定時は、確定文字列の 1 文字目が挿入される直前 (= 再描画の前) に未確定文字列を消す。
  -- これで確定の前後どちらのフレームにも、未確定文字列と確定文字列が二重に映らない
  -- (Preedit("") による消去は遅らせてあるので、確定ではこちらが先に効く)。未確定文字列が
  -- ある間はキー入力が IME に渡って Neovim には届かないので、ここで挿入される文字は
  -- 確定文字列に限られる。
  vim.api.nvim_create_autocmd("InsertCharPre", {
    group = group,
    callback = function()
      clear()
    end,
  })
  -- 保険: 未確定のまま挿入モードやウィンドウを離れたら残骸を消す。
  vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave", "WinLeave" }, {
    group = group,
    callback = function()
      clear()
    end,
  })

  -- Neovide は両ハンドラを nvim__exec_lua_fast で呼ぶ。fast な RPC は受信した瞬間に (Neovim が
  -- 何かの処理の途中でも) 実行されるため、ここでは番号を振って main loop に回すだけにする。
  _G.neovide.preedit_handler = function(text, s, e)
    received = received + 1
    local n = received
    vim.schedule(function()
      on_preedit(n, type(text) == "string" and text or "", s, e)
    end)
  end
  -- 確定そのものは既定の実装 (nvim_input) に任せる。続くキー入力と同じ入力キューに積まれるので、
  -- 確定文字列と後続のキーの順序が入れ替わらない。ここでは確定した時点を記録するだけ。
  local commit = _G.neovide.commit_handler
  if type(commit) == "function" then
    _G.neovide.commit_handler = function(...)
      committed = received
      return commit(...)
    end
  end
end

return M
