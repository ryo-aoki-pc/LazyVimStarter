-- OS の IME を Neovim のモードに追従させる (Linux = ibus / Windows = zenhan・im-select)。
--
-- なぜ自前で書くか:
--  - Neovim には 'imactivatefunc' / 'imstatusfunc' が存在しない (Vim 専用オプションで、
--    Neovim では "Unknown option" になる)。'iminsert' / 'imsearch' も GUI 用の残骸で
--    端末では何も起きない。つまり IME を制御する native なフックは一切なく、
--    外部プロセスで IME デーモンを叩く以外に手段がない。
--  - tmux の 'update-environment' に WAYLAND_DISPLAY が含まれないため、既存の tmux
--    セッション内で起動した nvim には DISPLAY=:0 しか継承されない。この状態で ibus の
--    クライアント (ibus CLI や libibus) はバスファイルを "<machine-id>-unix-0" (X11 用)
--    の名前で探し、Wayland セッションの "<machine-id>-unix-wayland-0" を見つけられず
--    "Can't connect to IBus" で失敗する。既存のプラグイン (im-select.nvim 等) はここで
--    黙って無効化されるため、バスアドレスを自前で解決する必要がある。
--
-- 状態モデル: ibus の global engine 名だけを真実とする ("anthy" = 日本語 / "xkb:us::eng" = 英数)。
-- anthy 内部の入力モード (ひらがな⇔Latin) は panel (gnome-shell) にしか publish されず
-- D-Bus から観測できないため、README の手順で anthy の on_off ショートカットから
-- Ctrl+J / Ctrl+space を外し、内部モードが動かないようにしてある。これにより
-- 「engine 名 = IME の状態」が常に成立し、<C-j> も Neovim まで届くようになる。
--
-- 状態は GlobalEngineChanged シグナル (gdbus monitor 常駐) で push されるので、
-- Super+Space など OS 側の切り替えも検知できる。ポーリングは行わない。

local uv = vim.uv or vim.loop

local M = {}

M.config = {
  enabled = true,
  -- 挿入を抜けた時点で日本語だったバッファは、次にそのバッファで挿入に入る時に自動復帰する。
  sticky = true,
  -- "signal": gdbus monitor を常駐させて GlobalEngineChanged を購読する (既定・推奨)。
  -- "poll"  : 挿入モードの間だけ 400ms 間隔で問い合わせる (monitor が使えない環境の保険)。
  -- "off"   : 自前の書き込み結果だけを信じる (OS 側の切り替えは検知できない)。
  watch = "signal",
  -- guicursor で挿入モードのカーソル色を変える。
  -- 注: tmux-256color には Cs/Cr が無く Neovim は OSC 12 を出さないため、tmux 越しでは
  --     terminal-overrides の設定が別途必要 (README 参照)。無くても無害な no-op。
  cursor = true,
  ibus = { ja = "anthy", ascii = "xkb:us::eng" },
}

local IBUS_DEST = "org.freedesktop.IBus"
local IBUS_PATH = "/org/freedesktop/IBus"

local state = {
  backend = nil, ---@type table|nil
  value = nil, ---@type string|nil 最後に観測したバックエンド値 (nil = 不明)
  desired = nil, ---@type string|nil 投入したい値 (コアレス用)
  inflight = false,
  -- gnome-shell が最後に「自分で」有効化したエンジン (= gnome-shell の内部状態)。
  -- 終了・中断時にここへ戻すことで、OS 側の入力ソース切替が壊れたままにならないようにする。
  shell_value = nil, ---@type string|nil
  expected = {}, ---@type string[] 自分が要求した変更 (シグナルの発生元を切り分けるため)
  watcher = nil,
  watch_fails = 0,
  poll = nil,
}

-- ibus: バスアドレスの解決 ----------------------------------------------------

local addr_cache = nil

-- $IBUS_ADDRESS → ~/.config/ibus/bus/ の最新ファイル、の順で解決する。
-- バスファイルは X11 と Wayland で別名 ("...-unix-0" / "...-unix-wayland-0") になり、
-- セッションを跨ぐと古いものが残る。名前で決め打ちせず mtime が最新のものを採り、
-- 生存確認で古いものを弾く方が、環境変数の欠落に強い。
local function resolve_address()
  local env = vim.env.IBUS_ADDRESS
  if env and env ~= "" then
    return env
  end
  local dir = (vim.env.HOME or "") .. "/.config/ibus/bus"
  local it = uv.fs_scandir(dir)
  if not it then
    return nil
  end
  local newest, newest_mtime = nil, -1
  while true do
    local name = uv.fs_scandir_next(it)
    if not name then
      break
    end
    local path = dir .. "/" .. name
    local st = uv.fs_stat(path)
    if st and st.type == "file" and st.mtime.sec > newest_mtime then
      newest, newest_mtime = path, st.mtime.sec
    end
  end
  if not newest then
    return nil
  end
  local ok, lines = pcall(vim.fn.readfile, newest)
  if not ok then
    return nil
  end
  local addr, pid
  for _, line in ipairs(lines) do
    addr = addr or line:match("^IBUS_ADDRESS=(.+)$")
    pid = pid or line:match("^IBUS_DAEMON_PID=(%d+)$")
  end
  if not addr or not pid then
    return nil
  end
  -- PID の生存確認だけでは PID 使い回しで無関係のプロセスを掴み得るので comm も照合する。
  local okc, comm = pcall(vim.fn.readfile, "/proc/" .. pid .. "/comm")
  if not okc or (comm[1] or "") ~= "ibus-daemon" then
    return nil
  end
  -- ソケットの実在確認 (デーモン再起動直後にバスファイルだけ古い、を弾く)。
  local sock = addr:match("unix:path=([^,]+)")
  if sock and not uv.fs_stat(sock) then
    return nil
  end
  return addr
end

local function address()
  if not addr_cache then
    addr_cache = resolve_address()
  end
  return addr_cache
end

-- 外部コマンドが失敗したらアドレスと観測値を捨て、次回に再解決させる。
local function invalidate()
  addr_cache = nil
  state.value = nil
end

-- ibus: 外部コマンドの選択 ----------------------------------------------------

-- /usr/bin/ibus の実装はディストリで割れる。Fedora 系は長く Python スクリプトで
-- 起動に 150ms 以上かかったが、RHEL 10 の ibus 1.5.32 は ELF バイナリで数 ms。
-- 先頭 2 バイトを読むだけで判別できるので、スクリプト実装のときだけ候補から外す。
local function is_elf(path)
  local f = io.open(path, "rb")
  if not f then
    return false
  end
  local magic = f:read(2)
  f:close()
  return magic == "\127E"
end

-- busctl を第一候補にする: systemd 同梱で必ず /usr/bin にあり、出力
-- `v (...) "IBusEngineDesc" 0 "anthy" ...` が最も素直に parse できる。
local function pick_tool()
  for _, name in ipairs({ "busctl", "gdbus", "ibus" }) do
    local path = vim.fn.exepath(name)
    if path ~= "" and (name ~= "ibus" or is_elf(path)) then
      return name
    end
  end
  return nil
end

-- バックエンド ----------------------------------------------------------------
--
-- コア (直列化・コアレス・sticky・表示) はバックエンド非依存。バックエンドは
-- 「値の集合 (ja/ascii)」と「set/get のコマンド」「出力の parse」だけを持つ。
-- watch は push 通知がある場合のみ実装する (ibus の GlobalEngineChanged)。

local function ibus_backend()
  if vim.fn.has("win32") == 1 then
    return nil
  end
  local tool = pick_tool()
  if not tool or not address() then
    return nil
  end
  return {
    name = "ibus",
    ja = M.config.ibus.ja,
    ascii = M.config.ibus.ascii,

    cmd_set = function(value)
      local addr = address()
      if not addr then
        return nil
      end
      if tool == "busctl" then
        return { "busctl", "--address=" .. addr, "call", IBUS_DEST, IBUS_PATH, IBUS_DEST, "SetGlobalEngine", "s", value }
      elseif tool == "gdbus" then
        -- stylua: ignore
        return {
          "gdbus", "call", "--address", addr, "--dest", IBUS_DEST, "--object-path", IBUS_PATH,
          "--method", IBUS_DEST .. ".SetGlobalEngine", value,
        }
      end
      -- ibus CLI にはアドレスを環境変数で渡す (vim.system の env は既存環境にマージされる)。
      return { "ibus", "engine", value }, { IBUS_ADDRESS = addr }
    end,

    cmd_get = function()
      local addr = address()
      if not addr then
        return nil
      end
      if tool == "busctl" then
        return { "busctl", "--address=" .. addr, "get-property", IBUS_DEST, IBUS_PATH, IBUS_DEST, "GlobalEngine" }
      elseif tool == "gdbus" then
        -- stylua: ignore
        return {
          "gdbus", "call", "--address", addr, "--dest", IBUS_DEST, "--object-path", IBUS_PATH,
          "--method", "org.freedesktop.DBus.Properties.Get", IBUS_DEST, "GlobalEngine",
        }
      end
      return { "ibus", "engine" }, { IBUS_ADDRESS = addr }
    end,

    -- GlobalEngine は IBusEngineDesc 構造体で返る。engine 名は型名の次の文字列。
    --   busctl: v (sa{sv}ss...) "IBusEngineDesc" 0 "anthy" "Anthy" ...
    --   gdbus : (<<('IBusEngineDesc', @a{sv} {}, 'anthy', 'Anthy', ...)>>,)
    --   ibus  : anthy
    parse = function(out)
      out = out or ""
      if tool == "busctl" then
        return out:match('"IBusEngineDesc"%s+%d+%s+"([^"]+)"')
      elseif tool == "gdbus" then
        return out:match("'IBusEngineDesc'.-'([^']+)'")
      end
      return vim.trim(out):match("^[%w%-_:%.]+$")
    end,

    -- gdbus monitor を 1 本だけ常駐させ GlobalEngineChanged を購読する。
    -- 出力実測: /org/freedesktop/IBus: org.freedesktop.IBus.GlobalEngineChanged ('anthy',)
    watch = function(on_value)
      if vim.fn.exepath("gdbus") == "" then
        return nil
      end
      local addr = address()
      if not addr then
        return nil
      end
      local function handle(data)
        for line in data:gmatch("[^\r\n]+") do
          local name = line:match("GlobalEngineChanged%s*%('([^']+)'")
          if name then
            on_value(name)
          end
        end
      end
      -- stylua: ignore
      return { "gdbus", "monitor", "--address", addr, "--dest", IBUS_DEST, "--object-path", IBUS_PATH }, handle
    end,
  }
end

-- Windows: zenhan.exe は IME の ON/OFF を直接叩く (1 = ON / 0 = OFF)。
-- 引数なしの実行で現在状態を返す実装だが、版によっては何も出さないため parse 失敗時は
-- 「自前の書き込み結果だけを信じる」動作に自然に縮退する (state.value が更新されないだけ)。
local function zenhan_backend()
  if vim.fn.has("win32") ~= 1 or vim.fn.executable("zenhan") ~= 1 then
    return nil
  end
  return {
    name = "zenhan",
    ja = "1",
    ascii = "0",
    cmd_set = function(value)
      return { "zenhan", value }
    end,
    cmd_get = function()
      return { "zenhan" }
    end,
    parse = function(out)
      return vim.trim(out or ""):match("^[01]$")
    end,
  }
end

-- Windows: im-select.exe は入力ロケールを切り替える (1041 = 日本語 / 1033 = 英語(US))。
-- zenhan と違い「IME の変換 ON/OFF」ではなく「入力方式そのもの」の切替なので、
-- 日本語に戻したとき半角英数モードで復帰することがある。zenhan があればそちらを優先する。
local function im_select_backend()
  if vim.fn.has("win32") ~= 1 or vim.fn.executable("im-select") ~= 1 then
    return nil
  end
  return {
    name = "im-select",
    ja = "1041",
    ascii = "1033",
    cmd_set = function(value)
      return { "im-select", value }
    end,
    cmd_get = function()
      return { "im-select" }
    end,
    parse = function(out)
      return vim.trim(out or ""):match("^%d+$")
    end,
  }
end

local function select_backend()
  for _, build in ipairs({ ibus_backend, zenhan_backend, im_select_backend }) do
    local ok, b = pcall(build)
    if ok and b then
      return b
    end
  end
  return nil
end

-- 観測値の更新と再描画 --------------------------------------------------------

local function observe(value)
  if state.value == value then
    return
  end
  state.value = value
  if M.config.cursor then
    M.apply_cursor()
  end
  -- lualine は既定 1 秒タイマで再描画するが、状態変化は即座に見せたい。
  pcall(vim.cmd.redrawstatus)
end

-- gnome-shell は ibus の global engine を「外部から」変えられても自分の内部状態を
-- 更新しない (gsettings の current を書いても追従しないことを実測で確認済み)。
-- そのため nvim が裏でエンジンを変えると gnome-shell の認識がズレ、Super+Space が
-- 古い状態を基準に動いてしまう。ズレを残さないよう「gnome-shell が最後に有効化した
-- エンジン」を覚えておき、終了・中断時にそこへ戻す。
-- 自分が出した変更かどうかは、要求した値を FIFO に積んでシグナルと突き合わせて判定する。
local function observe_external(value)
  if state.expected[1] == value then
    table.remove(state.expected, 1)
  else
    -- 自分の要求ではない = gnome-shell (Super+Space やインジケータ) による変更。
    -- この瞬間は gnome-shell の認識と実体が一致している。
    state.expected = {}
    state.shell_value = value
  end
  observe(value)
end

-- 書き込み (直列化 + コアレス) -----------------------------------------------

-- i / <Esc> / i を高速に往復しても外部プロセスは常に 1 本以下に保つ。実行中に新しい
-- 要求が来たら desired を上書きするだけで、完了時に差分があればもう一度だけ投げる
-- (last-write-wins)。これで「キー入力ごとに spawn」は原理的に起きない。
local function pump()
  if state.inflight or not state.desired or not state.backend then
    return
  end
  local want = state.desired
  -- すでにその状態なら何もしない。<Esc> の大半はここで終わり spawn すらしない。
  if state.value == want then
    state.desired = nil
    return
  end
  local cmd, env = state.backend.cmd_set(want)
  if not cmd then
    state.desired = nil
    return
  end
  state.inflight = true
  -- 続いて飛んでくる GlobalEngineChanged が「自分由来」だと分かるようにしておく。
  table.insert(state.expected, want)
  vim.system(cmd, { text = true, env = env, timeout = 1000 }, function(res)
    state.inflight = false
    if res.code == 0 then
      vim.schedule(function()
        observe(want)
        if state.desired == want then
          state.desired = nil
        end
        pump()
      end)
    else
      -- ibus-daemon の再起動などでアドレスが失効した可能性が高い。次回に再解決させる。
      vim.schedule(function()
        invalidate()
        state.desired = nil
        state.expected = {}
      end)
    end
  end)
end

local function request(value)
  if not state.backend then
    return
  end
  state.desired = value
  pump()
end

function M.ja()
  if state.backend then
    request(state.backend.ja)
  end
end

function M.ascii()
  if state.backend then
    request(state.backend.ascii)
  end
end

function M.toggle()
  if not state.backend then
    return
  end
  request(M.is_ja() and state.backend.ascii or state.backend.ja)
end

-- 問い合わせ (実測値で状態を確定させる) ---------------------------------------

function M.sync()
  if not state.backend then
    return
  end
  local cmd, env = state.backend.cmd_get()
  if not cmd then
    return
  end
  vim.system(cmd, { text = true, env = env, timeout = 1000 }, function(res)
    if res.code ~= 0 then
      vim.schedule(invalidate)
      return
    end
    local value = state.backend.parse(res.stdout)
    if value then
      vim.schedule(function()
        observe(value)
      end)
    end
  end)
end

-- 監視 (push) ----------------------------------------------------------------

local start_watcher
start_watcher = function()
  if state.watcher or not state.backend or not state.backend.watch then
    return
  end
  local cmd, handle_line = state.backend.watch(function(value)
    vim.schedule(function()
      observe_external(value)
    end)
  end)
  if not cmd then
    return
  end
  state.watcher = vim.system(cmd, {
    text = true,
    stdout = function(err, data)
      if not err and data then
        handle_line(data)
      end
    end,
  }, function()
    -- ibus-daemon の再起動やログアウトで落ちる。指数バックオフで数回だけ張り直し、
    -- 諦めたら静かに黙る (UI を壊さないことを最優先する)。
    state.watcher = nil
    state.watch_fails = state.watch_fails + 1
    if state.watch_fails > 5 then
      return
    end
    vim.schedule(function()
      invalidate()
      vim.defer_fn(start_watcher, 2000 * state.watch_fails)
    end)
  end)
end

-- monitor が使えない環境用の保険。挿入モードの間だけ回し、挿入を抜けたら必ず止める。
-- アイドル時のプロセス生成はゼロ。
local function poll_start()
  if M.config.watch ~= "poll" or state.poll then
    return
  end
  state.poll = uv.new_timer()
  state.poll:start(400, 400, function()
    vim.schedule(M.sync)
  end)
end

local function poll_stop()
  if state.poll then
    state.poll:stop()
    state.poll:close()
    state.poll = nil
  end
end

-- 表示 -----------------------------------------------------------------------

function M.is_ja()
  return state.backend ~= nil and state.value == state.backend.ja
end

-- lualine 用。state.value は watcher と自前の書き込みで更新されるキャッシュなので、
-- 描画のたびに外部プロセスが起きることはない。
function M.status()
  if not state.backend or state.value == nil then
    return ""
  end
  return M.is_ja() and "あ" or "A"
end

-- カーソル色。guicursor からは固定のハイライトグループ (IMECursor) を参照させ、
-- 状態変化ではそのグループの定義だけを差し替える ('guicursor' 文字列を組み立て直さない)。
function M.apply_cursor()
  if M.is_ja() then
    vim.api.nvim_set_hl(0, "IMECursor", { bg = "#ff9e64", fg = "#1a1b26" })
  else
    vim.api.nvim_set_hl(0, "IMECursor", { link = "Cursor" })
  end
end

-- モード連動 (autocmds.lua から呼ばれる) --------------------------------------

function M.on_insert_enter(buf)
  if not state.backend then
    return
  end
  poll_start()
  -- sticky でないバッファでも明示的に英数を投げる (他アプリで ON のまま戻ってきた場合の保険)。
  -- 「既にその状態なら spawn しない」ので通常は無コスト。
  if M.config.sticky and buf and vim.b[buf].ime_sticky then
    M.ja()
  else
    M.ascii()
  end
end

function M.on_insert_leave(buf)
  if not state.backend then
    return
  end
  if M.config.sticky and buf and vim.api.nvim_buf_is_valid(buf) then
    -- 「抜けた瞬間に日本語だったか」を記録する。state.value は watcher 由来の実測値なので、
    -- OS のホットキーで切り替えられていても正しく拾える。
    vim.b[buf].ime_sticky = M.is_ja()
  end
  M.ascii()
  poll_stop()
end

-- 終了・中断時に「gnome-shell が認識しているエンジン」へ戻す。
-- これをしないと nvim が強制した英数のまま gnome-shell の内部状態とズレが残り、
-- OS 側の入力ソース切替 (Super+Space) が一手ぶん噛み合わなくなる。
---@param blocking boolean|nil 終了直前は同期的に投げる (非同期だと nvim の終了に間に合わない)
function M.restore_shell(blocking)
  if not state.backend then
    return
  end
  local target = state.shell_value or state.backend.ascii
  if not blocking then
    request(target)
    return
  end
  if state.value == target then
    return
  end
  local cmd, env = state.backend.cmd_set(target)
  if not cmd then
    return
  end
  -- 1 回 7ms 程度の外部コマンドなので、終了直前に待っても体感されない。
  pcall(function()
    vim.system(cmd, { text = true, env = env, timeout = 1000 }):wait(1500)
  end)
end

function M.teardown()
  poll_stop()
  if state.watcher then
    pcall(function()
      state.watcher:kill(15)
    end)
    state.watcher = nil
  end
end

-- setup ----------------------------------------------------------------------

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  if not M.config.enabled then
    return
  end
  -- headless (nvim --headless "+Lazy! sync" 等) では IME を触る意味がなく、
  -- 余計なプロセスも起こしたくないので完全に何もしない。
  if #vim.api.nvim_list_uis() == 0 then
    return
  end
  state.backend = select_backend()
  if not state.backend then
    -- IME デーモンが居ない / 対応コマンドが無い。静かに降りる (エラーは出さない)。
    return
  end

  if M.config.cursor then
    -- 既定の guicursor は "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"。後勝ちなので
    -- i-ci-ve を名前付きグループ付きで append すれば挿入モードのカーソルだけ色が付く。
    vim.opt.guicursor:append("i-ci-ve:ver25-IMECursor")
    M.apply_cursor()
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("user_ime_cursor", { clear = true }),
      callback = M.apply_cursor,
    })
  end

  if M.config.watch == "signal" then
    start_watcher()
  end

  -- 起動時点のエンジンを同期的に 1 回だけ読む (7ms 程度)。これが gnome-shell の
  -- 認識しているエンジンであり、終了時に戻す先になる。非同期にすると直後の
  -- ascii() が先に走って「nvim が英数にした後の値」を読んでしまう。
  local cmd, env = state.backend.cmd_get()
  if cmd then
    local ok, res = pcall(function()
      return vim.system(cmd, { text = true, env = env, timeout = 1000 }):wait(1500)
    end)
    if ok and res and res.code == 0 then
      local value = state.backend.parse(res.stdout)
      if value then
        state.shell_value = value
        observe(value)
      end
    end
  end
  M.ascii() -- 起動直後は必ず英数 (直前のアプリが日本語のままでもノーマルモードを守る)
end

function M.enabled()
  return state.backend ~= nil
end

return M
