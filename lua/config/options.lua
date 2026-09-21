-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
-- 先頭の ucs-bom は必須。外すと BOM 付き UTF-8 (Windows のメモ帳や Excel の CSV) が
-- 先頭に U+FEFF を抱えたまま開き 'bomb' も立たず、BOM 付き UTF-16 (PowerShell 5.1 の
-- Out-File 既定) も判定できない。また cp932 はほぼ任意のバイト列を受理するため、
-- その後ろに並べたエンコーディングは事実上到達しない (:help 'fileencodings')。
-- そのため cp932 より後ろには「推測で当てにいく」ものを置かない。
vim.opt.fileencodings = { "ucs-bom", "utf-8", "cp932", "euc-jp" }
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
    -- Remove-Alias は PowerShell 6.0 以降にしか無い。5.1 で呼ぶと存在しないコマンドレット
    -- への呼び出しになり -ErrorAction では抑止できず、shellcmdflag は全てのシェル呼び出しに
    -- 前置されるので :! :make :grep すべてにエラー行が混ざる ($PSStyle と同じ理由でガードする)。
    .. (pwsh and "Remove-Alias -Force -ErrorAction SilentlyContinue tee;" or "")
  -- shellredir / shellpipe とも Out-File で書き出す。tee alias を外した pwsh では
  -- `| tee` が外部 tee.exe を探しにいき、素の Windows には無いので :grep (LazyVim は
  -- grepprg=rg) や :make が「tee は認識されません」で失敗する。
  -- なお %% のエスケープは必須 (素の % は E1577 になる)。
  vim.opt.shellredir = '2>&1 | %%{ "$_" } | Out-File %s; exit $LastExitCode'
  vim.opt.shellpipe = '2>&1 | %%{ "$_" } | Out-File %s; exit $LastExitCode'
  vim.opt.shellquote = ""
  vim.opt.shellxquote = ""
end

-- git diff の品質改善: ハンク分割を git 同等の histogram にし、:diffsplit 系
-- (gitsigns の <leader>ghd など) も左右分割にする。
-- indent-heuristic と linematch は Neovim 0.12 では既定で入っている
-- (既定値: internal,filler,closeoff,indent-heuristic,inline:char,linematch:40)。
-- そのまま append すると indent-heuristic は重複で無視され、linematch は 2 つ並んで
-- しまうため、上限を上げたい linematch は既定値を remove してから入れ直す。
vim.opt.diffopt:remove("linematch:40")
vim.opt.diffopt:append({ "algorithm:histogram", "linematch:60", "vertical" })

-- 日本語 (マルチバイト) 向けの整形挙動:
--  m: マルチバイト文字の間でも折り返しを許可する。日本語は空白で区切られないため、
--     これがないと gq や textwidth の自動改行が日本語の長文を折り返せない。
--  M: 行連結 (J / gq の再整形) でマルチバイト文字の前後に空白を挿入しない
--     (「〜です。」+「しかし〜」の連結で不要な半角空白が入るのを防ぐ)。
-- LazyVim の既定 "jcroqlnt" はグローバル代入で、このファイルはその後に読まれるため append でよい。
-- 'formatoptions' はバッファローカルだがグローバル値が初期値になり、散文系の ftplugin
-- (markdown / text / gitcommit) は +=/-= の差分操作しかしないため、グローバル append で行き渡る。
-- (ps1 や nu など一部の ftplugin は setlocal formatoptions= で絶対代入するので mM は落ちるが、
--  日本語の文章を書く filetype ではないため実害はない。)
vim.opt.formatoptions:append("mM")

-- 全角括弧でも % ジャンプと matchparen の対応強調を効かせる (日本語の文章・技術文書用)。
-- 'matchpairs' も「バッファローカル + グローバル初期値」で ftplugin は追記しかしないため append で足りる。
vim.opt.matchpairs:append({ "（:）", "「:」", "『:』", "【:】" })

-- 'ambiwidth' は意図的に既定 (single) のまま変えない。
-- East Asian Ambiguous 幅の文字 (○ ± ① → など) を何桁で描くかは「端末側の設定」と
-- 「Neovim 側の設定」が一致していないと、その文字を含む行の桁が丸ごとずれる。
-- Neovim 既定の single は WezTerm 既定の treat_east_asian_ambiguous_width_as_wide=false と
-- 一致しているため、現状で正しい。端末側を wide に変えるときだけ、ここを "double" に
-- 揃えること (片方だけ変えるのが「端末で日本語表示が崩れる」最頻の原因)。
