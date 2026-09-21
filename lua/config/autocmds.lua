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

-- OS の IME (ibus/anthy) を Neovim のモードに追従させる。実体は lua/config/ime.lua。
-- IME デーモンが居ない / headless / 対応コマンドが無い環境では setup() が静かに降り、
-- 以下のコールバックもすべて no-op になるため、ここでは無条件に呼んでよい。
local ime = require("config.ime")
ime.setup()

local ime_group = vim.api.nvim_create_augroup("user_ime", { clear = true })

-- 挿入を抜けたら必ず英数に戻す。ノーマルモードのキー (dd, ciw, ...) が IME に食われない
-- ための最優先処理なので、モード遷移の直前に発火する InsertLeavePre を使う
-- (InsertLeave より一手早い)。i_CTRL-O は挿入モードを抜けないため発火せず、
-- 一時ノーマルコマンドの最中に IME が落ちる事故は起きない。
vim.api.nvim_create_autocmd("InsertLeavePre", {
  group = ime_group,
  callback = function(ev)
    ime.on_insert_leave(ev.buf)
  end,
})

-- 挿入に入る時の復帰。前回そのバッファで日本語のまま抜けていたら日本語に戻す (sticky)。
vim.api.nvim_create_autocmd("InsertEnter", {
  group = ime_group,
  callback = function(ev)
    ime.on_insert_enter(ev.buf)
  end,
})

-- コマンドライン。: や / で IME が生きていると Ex コマンドも検索も打てない。
-- 日本語検索はローマ字のままマッチする vim-kensaku が担うので、常に英数でよい。
vim.api.nvim_create_autocmd({ "CmdlineEnter", "CmdlineLeave" }, {
  group = ime_group,
  callback = ime.ascii,
})

-- Neovim を離れている間に OS 側で切り替えられている可能性があるため、復帰時に実測し直す。
-- watch="signal" ならシグナルで拾えているはずだが、監視が落ちていた場合の保険。
vim.api.nvim_create_autocmd("FocusGained", {
  group = ime_group,
  callback = ime.sync,
})

-- 終了・中断時: gnome-shell が認識しているエンジンへ戻す。
-- gnome-shell は外部からの engine 変更を観測しないため、nvim が強制した英数のまま
-- 抜けると gnome-shell の内部状態とズレが残り、Super+Space での入力ソース切替が
-- 一手ぶん噛み合わなくなる。nvim を起動する前の状態に戻して抜けるのが正しい。
vim.api.nvim_create_autocmd({ "VimLeavePre", "VimSuspend" }, {
  group = ime_group,
  callback = function(ev)
    ime.restore_shell(true)
    if ev.event == "VimLeavePre" then
      ime.teardown()
    end
  end,
})

-- 中断から戻ったらノーマルモードに居るので、また英数へ落として実体を測り直す。
vim.api.nvim_create_autocmd("VimResume", {
  group = ime_group,
  callback = function()
    ime.ascii()
    ime.sync()
  end,
})

-- 全角スペース (U+3000) の可視化。半角スペースと見分けがつかないまま混入すると
-- Markdown のリストのネストやコードフェンス、YAML front matter が静かに壊れる。
-- IME を使う運用では実際に起きる事故なので常時見えるようにしておく。
-- 'listchars' は U+3000 を表現できず (space/trail/multispace/nbsp のいずれでもない)、
-- 'list' を有効にすると全ての空白が出て騒がしいため matchadd を使う。matchadd は
-- ウィンドウローカルなので、ウィンドウが作られるたびに (w: の番兵で重複を防いで) 張る。
local zenkaku_group = vim.api.nvim_create_augroup("user_zenkaku_space", { clear = true })

-- ハイライト定義は colorscheme の切り替えで消えるので張り直す。特定の colorscheme に
-- 依存しないよう、色は直接指定せず「波線の下線」で示す (背景色だと選択範囲と紛らわしい)。
local function zenkaku_hl()
  vim.api.nvim_set_hl(0, "ZenkakuSpace", { undercurl = true, sp = "#f7768e" })
end
vim.api.nvim_create_autocmd("ColorScheme", { group = zenkaku_group, callback = zenkaku_hl })
zenkaku_hl()

local function zenkaku_match()
  if vim.w.zenkaku_space_match then
    return
  end
  vim.w.zenkaku_space_match = vim.fn.matchadd("ZenkakuSpace", "\\%u3000", -1)
end
vim.api.nvim_create_autocmd({ "BufWinEnter", "WinNew" }, { group = zenkaku_group, callback = zenkaku_match })

-- autocmds.lua は VeryLazy で読まれるため、起動時に既に開かれているウィンドウの
-- BufWinEnter は取り逃がしている。最初の 1 回だけ現存ウィンドウにも張る。
for _, win in ipairs(vim.api.nvim_list_wins()) do
  vim.api.nvim_win_call(win, zenkaku_match)
end
