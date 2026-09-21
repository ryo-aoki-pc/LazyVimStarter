-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- 注: j/k の「折り返し行を表示行単位で移動」は LazyVim が既定で入れている
-- (lazyvim/config/keymaps.lua。<Down>/<Up> にも同じものを張る) ため、ここでは定義しない。
local map = vim.keymap.set

-- IME (OS 側) のトグル。skkeleton の <C-j> の筋肉記憶を引き継ぐ。
-- 挿入モードとコマンドラインのみに張る: ノーマルモードの <C-j> は LazyVim が <C-w>j
-- (下のウィンドウへ移動) に、ターミナルモードの <C-j> も LazyVim が使っているため奪わない。
--
-- 前提: 既定では Ctrl+J が anthy の on_off ショートカットに消費されて Neovim まで届かない。
-- README の gsettings 手順で on_off から Ctrl+J / Ctrl+space を外しておくこと
-- (外すと preedit が無いときの Ctrl+J は anthy の commit ハンドラが素通しする)。
map({ "i", "c" }, "<C-j>", function()
  require("config.ime").toggle()
end, { desc = "IME トグル (あ/A)" })
