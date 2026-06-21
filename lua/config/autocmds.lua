-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- LazyVim の lazyvim_wrap_spell は markdown/text/gitcommit 等で spell を有効化する。
-- そのままだと日本語が全て綴り誤り扱いになるため、spelllang に擬似リージョン "cjk" を足して
-- East Asian 文字を除外する。埋め込まれた英単語のスペルチェックは "en" で維持される。
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("user_cjk_spell", { clear = true }),
  pattern = { "markdown", "text", "gitcommit", "plaintex", "typst" },
  callback = function()
    vim.opt_local.spelllang = { "en", "cjk" }
  end,
})

-- gitsigns で hunk を stage/unstage/reset すると `User GitSignsChanged` が発火する。
-- diffview を開いている間だけ差分ビューを即時更新し、file panel と左ペイン(index 表示)を最新化する。
-- pcall: diffview 未ロード時の require 失敗等で autocmd を落とさないため。
-- get_current_view(): diffview 未表示時に無駄な :DiffviewRefresh を撃たないため。
vim.api.nvim_create_autocmd("User", {
  pattern = "GitSignsChanged",
  group = vim.api.nvim_create_augroup("diffview_refresh_on_gitsigns", { clear = true }),
  callback = function()
    pcall(function()
      if require("diffview.lib").get_current_view() then
        vim.cmd("DiffviewRefresh")
      end
    end)
  end,
})
