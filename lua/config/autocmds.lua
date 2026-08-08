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

-- Markdown の箇条書きを <CR> と o/O で自動継続する (プラグイン不要)。
-- Neovim 標準の ftplugin (runtime/ftplugin/markdown.vim) は comments=fb:*,fb:-,fb:+,n:> と
-- fo-=r fo-=o を設定するため、既定では継続されない。f フラグ (「先頭行のみ」= 継続させない) を
-- 外し、formatoptions に r (<CR> で継続) と o (o/O で継続) を戻して実現する。
-- ユーザー定義の FileType autocmd は ftplugin より後に走るため、ここでの setlocal が最終値になる。
-- b フラグにより「記号 + 空白」の行だけが継続対象 (*強調* などへの誤爆なし)。n:> は引用の gq 整形用に維持。
-- トレードオフ:
--  - 番号リスト (1. 2. ...) の自動連番は不可 ('comments' では表現できない)
--  - 空の箇条書きで <CR> しても記号は自動では消えない (手動削除 or <C-u>)
--  - より高機能な bullets.vim 等はプラグイン追加に見合わないため採用しない
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("user_markdown_lists", { clear = true }),
  pattern = "markdown",
  callback = function()
    vim.opt_local.comments = { "b:*", "b:-", "b:+", "n:>" }
    vim.opt_local.formatoptions:append("ro")
  end,
})
