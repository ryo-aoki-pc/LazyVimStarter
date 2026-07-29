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
