-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.fileencodings = { "utf-8", "cp932", "euc-jp", "utf-16le" }
vim.opt.guifont = "HackGen Console NF:h12"
vim.opt.relativenumber = false
vim.opt.wildmode = { "longest", "list" }

-- クロスプラットフォーム改行: 常に LF を優先し、CRLF ファイルも透過的に扱う。
-- (Neovim の既定は Windows で "dos,unix" のため、両 OS で統一するには明示が必要)
vim.opt.fileformats = { "unix", "dos" }

-- Windows の shell を PowerShell にする (:help shell-powershell の公式レシピ準拠)。
-- pwsh (PowerShell 7) があれば優先。コンソール入出力を UTF-8 に固定しないと
-- :! や外部コマンド出力の日本語が cp932 で文字化けするため、shellcmdflag で明示する。
if vim.fn.has("win32") == 1 then
  local pwsh = vim.fn.executable("pwsh") == 1
  vim.opt.shell = pwsh and "pwsh" or "powershell"
  vim.opt.shellcmdflag = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -Command "
    .. "[Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new();"
    .. "$PSDefaultParameterValues['Out-File:Encoding']='utf8';"
    -- $PSStyle は pwsh 7.2+ 専用 (Windows PowerShell 5.1 では存在せずエラーになる)
    .. (pwsh and "$PSStyle.OutputRendering='plaintext';" or "")
    .. "Remove-Alias -Force -ErrorAction SilentlyContinue tee;"
  vim.opt.shellredir = '2>&1 | %%{ "$_" } | Out-File %s; exit $LastExitCode'
  vim.opt.shellpipe = '2>&1 | %%{ "$_" } | tee %s; exit $LastExitCode'
  vim.opt.shellquote = ""
  vim.opt.shellxquote = ""
end

-- git diff の品質改善: ハンク分割を git 同等の histogram に、インデントを考慮した整形、
-- 変更行同士の行対応付け (linematch, Neovim 0.9+) で side-by-side 表示を見やすくする。
-- "vertical" は :diffsplit 系 (gitsigns の <leader>ghd など) も左右分割にするため。
vim.opt.diffopt:append({ "algorithm:histogram", "indent-heuristic", "linematch:60", "vertical" })

-- 日本語 (マルチバイト) 向けの整形挙動:
--  m: マルチバイト文字の間でも折り返しを許可する。日本語は空白で区切られないため、
--     これがないと gq や textwidth の自動改行が日本語の長文を折り返せない。
--  M: 行連結 (J / gq の再整形) でマルチバイト文字の前後に空白を挿入しない
--     (「〜です。」+「しかし〜」の連結で不要な半角空白が入るのを防ぐ)。
-- LazyVim の既定 "jcroqlnt" はグローバル代入で、このファイルはその後に読まれるため append でよい。
-- 'formatoptions' はバッファローカルだがグローバル値が初期値になり、ftplugin (markdown 等) は
-- +=/-= の差分操作しかしないため、グローバル append だけで全 filetype に行き渡る。
vim.opt.formatoptions:append("mM")

-- 全角括弧でも % ジャンプと matchparen の対応強調を効かせる (日本語の文章・技術文書用)。
-- 'matchpairs' も「バッファローカル + グローバル初期値」で ftplugin は追記しかしないため append で足りる。
vim.opt.matchpairs:append({ "（:）", "「:」", "『:』", "【:】" })
