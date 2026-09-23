-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- 注: j/k の「折り返し行を表示行単位で移動」は LazyVim が既定で入れている
-- (lazyvim/config/keymaps.lua。<Down>/<Up> にも同じものを張る) ため、ここでは定義しない。
local map = vim.keymap.set

-- IME (OS 側) のトグル。
-- 挿入モードとコマンドラインのみに張る: ノーマルモードの <C-j> は LazyVim が <C-w>j
-- (下のウィンドウへ移動) に、ターミナルモードの <C-j> も LazyVim が使っているため奪わない。
--
-- 前提: 既定では Ctrl+J が anthy の on_off ショートカットに消費されて Neovim まで届かない。
-- docs/setup.md の gsettings 手順で on_off から Ctrl+J / Ctrl+space を外しておくこと
-- (外すと preedit が無いときの Ctrl+J は anthy の commit ハンドラが素通しする)。
map({ "i", "c" }, "<C-j>", function()
  require("config.ime").toggle()
end, { desc = "IME トグル (あ/A)" })

-- * # のマルチバイト対応。組み込みの * は \<単語\> を検索するが、\< \> は文字クラス
-- (漢字 / ひらがな / カタカナ / 英数) の切り替わりにしか成立しない。日本語では
--  - <cword> が同じクラスの連続になる (「日本語検索」上で押すと漢字 5 文字丸ごと)
--  - 「を検索する」上で押した \<検索\> は「日本語検索」の中の「検索」に当たらない
-- ため、非 ASCII を含む単語は境界を付けずリテラル (\V) で検索する。ASCII だけの単語は
-- 組み込みのまま。「検索」だけを狙うなら visual 選択して * / # (選択文字列のリテラル検索)。
local function is_ascii(text)
  return not text:find("[\128-\255]")
end

-- / ? を feedkeys で実際に打つ。@/ と検索履歴・v:searchforward・hlsearch・[n/m] 表示が
-- 手入力と同じになり、"n" (noremap) なので lua/plugins/migemo.lua の <CR> フックも通らない。
local function search_literal(text, forward, count)
  local delim = forward and "/" or "?"
  local pattern = "\\V" .. (vim.fn.escape(text, "\\" .. delim):gsub("\n", "\\n"))
  vim.api.nvim_feedkeys((count or "") .. delim .. pattern .. "\r", "nx", false)
end

local function star(key, forward)
  return function()
    local count = vim.v.count > 0 and tostring(vim.v.count) or ""
    local word = vim.fn.expand("<cword>")
    if is_ascii(word) then
      vim.api.nvim_feedkeys(count .. key, "nx", false)
    else
      search_literal(word, forward, count)
    end
  end
end

for key, forward in pairs({ ["*"] = true, ["#"] = false, ["g*"] = true, ["g#"] = false }) do
  map("n", key, star(key, forward), { desc = "カーソル下の単語を検索 (日本語は境界なし)" })
end

local function visual_star(forward)
  return function()
    local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
    -- 選択を抜けて先頭に立ってから検索する。* は次の出現へ、# は前の出現へ進む
    vim.api.nvim_feedkeys(vim.keycode("<Esc>`<"), "nx", false)
    search_literal(table.concat(lines, "\n"), forward)
  end
end

map("x", "*", visual_star(true), { desc = "選択文字列を検索" })
map("x", "#", visual_star(false), { desc = "選択文字列を逆方向に検索" })
