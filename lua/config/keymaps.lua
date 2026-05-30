-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- 折り返した長い行 (日本語の文章など) では j/k を表示行単位で移動する。
-- count 指定時 (例: 5j) は通常の論理行移動を維持するので、相対行ジャンプとも両立する。
local map = vim.keymap.set
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = "Down (display line)" })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = "Up (display line)" })
