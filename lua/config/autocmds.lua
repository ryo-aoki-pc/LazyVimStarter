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
-- ための最優先処理。イベントではなく ModeChanged のパターンで拾うのが正確:
--  - InsertLeave は <C-c> で発火しない (:help InsertLeave の "But not for i_CTRL-C")。
--    取りこぼすと <C-c> で抜けた時に IME が日本語のまま残る。
--  - InsertLeavePre は <C-c> を拾えるが i_CTRL-O でも発火する (:help InsertLeavePre)。
--    <C-o>zz のたびに英数化 → sticky で復帰、と往復して busctl が 2 回余計に起動し、
--    あ/A の表示もちらつく。
--  - ModeChanged の "i*:n" なら <Esc> と <C-c> (どちらも遷移先 n) を拾い、
--    i_CTRL-O (遷移先 niI) は一致しないので除外できる。実測で確認済み。
-- 置換モード (R / Rv) も挿入と同じ扱いなので "R*:n" を併せて登録する。
vim.api.nvim_create_autocmd("ModeChanged", {
  group = ime_group,
  pattern = { "i*:n", "R*:n" },
  callback = function(ev)
    ime.on_insert_leave(ev.buf)
  end,
})

-- 挿入に入る時の復帰。前回そのバッファで日本語のまま抜けていたら日本語に戻す (sticky)。
-- InsertEnter は挿入・置換・仮想置換のいずれでも発火する。
vim.api.nvim_create_autocmd("InsertEnter", {
  group = ime_group,
  callback = function(ev)
    ime.on_insert_enter(ev.buf)
  end,
})

-- コマンドライン。: や / で IME が生きていると Ex コマンドも検索も打てない。
-- 日本語検索はローマ字のままマッチする vim-kensaku が担うので、常に英数でよい。
vim.api.nvim_create_autocmd("ModeChanged", {
  group = ime_group,
  pattern = "*:c*",
  callback = ime.ascii,
})

-- コマンドラインから挿入モードへ戻る経路 (挿入中の <C-r>= など)。
-- この場合 CmdlineLeave の後に InsertEnter は発火しないため、ここで復元しないと
-- 文章の途中で式レジスタを使っただけで英数に落ちたまま戻らなくなる。
-- なお CmdlineLeave 時点では mode() がまだ "c" なので、イベント側では判定できない
-- (実測済み)。ModeChanged なら遷移先がパターンに出るので取りこぼさない。
vim.api.nvim_create_autocmd("ModeChanged", {
  group = ime_group,
  pattern = "c*:i*",
  callback = function(ev)
    ime.on_insert_enter(ev.buf)
  end,
})

-- ターミナルモード。Insert* 系の autocmd は端末モードでは発火しない
-- (:help InsertEnter は挿入/置換/仮想置換のみ) ため、専用イベントで同じ面倒を見る。
-- これが無いと lazygit のコミットメッセージなどで日本語を打って <C-\><C-n> で抜けた時に
-- IME が日本語のまま残る。TermLeave は TermClose の後にも発火するので、
-- バッファの有効性は on_insert_leave 側のガードに任せる。
vim.api.nvim_create_autocmd("TermEnter", {
  group = ime_group,
  callback = function(ev)
    ime.on_insert_enter(ev.buf)
  end,
})
vim.api.nvim_create_autocmd("TermLeave", {
  group = ime_group,
  callback = function(ev)
    ime.on_insert_leave(ev.buf)
  end,
})

-- Neovim を離れている間に OS 側で切り替えられている可能性があるため、復帰時に実測し直す。
-- ただし sync() が直すのは表示用のキャッシュ (state.value) だけで、終了時の復帰先
-- (shell_value) は更新しない。あくまで「あ/A 表示がズレたままになる」ことへの保険。
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

-- ハイライト定義は colorscheme の切り替えで消えるので張り直す。背景色だと選択範囲と
-- 紛らわしいので波線の下線で示す (sp は tokyonight の赤に合わせた固定値)。
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
