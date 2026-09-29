-- GitLab プレビュー: 編集中の Markdown を GitLab の Markdown API で描かせ、ブラウザにライブで出す。
-- GitLab が描いた HTML をそのまま使うので、GLFM 固有の記法 ([[_TOC_]]・$`…`$・>>>・{+ +}・[~]・
-- アラート・#123 などの参照) も GitLab と同じに見える。数式と mermaid は GitLab と同じく、ページの JS が描く。
-- GitLab に届かない (トークンが無い・通信できない) ときは、ページの markdown-it で近似の表示にする。
--
-- 構成:
--   init.lua   (ここ) 状態・autocmd・描画のループ。公開するのは start / stop / toggle / open / url / is_running
--   gitlab.lua 送り先の決定・git remote の解析・curl での API の呼び出し
--   server.lua 127.0.0.1 の HTTP / SSE サーバーと、リポジトリの外を読ませない閉じ込め
--   libs.lua   ページが jsDelivr から読むライブラリの版と SRI
--   page/      ブラウザ側 (index.html / preview.js / preview.css)
-- 配線は lua/plugins/gitlab-preview.lua (<leader>cp と :GitLabPreview*)。
-- require しただけでは何もしない。
local gitlab = require("config.gitlab_preview.gitlab")
local server = require("config.gitlab_preview.server")

local M = {}

M.config = {
  debounce_ms = 300, -- 打鍵が止まってから送るまで
  scroll_ms = 80, -- カーソルの移動を送る間隔
  retry_ms = 30000, -- 通信の失敗・回数制限の後、GitLab に送らない時間
  reconnect_wait_ms = 1500, -- 開き直したとき、開いたままのタブが戻ってくるのを待つ時間
}

local state = nil ---@type table?
local page_cache = nil ---@type table?
local last_url = nil ---@type string? このセッションで最後に開いた URL

local function notify(msg, level)
  vim.notify("GitLab プレビュー: " .. msg, level or vim.log.levels.INFO)
end

-- page/ と libs.lua から、ページ (HTML・JS・CSS) と CSP を作る
local function load_page()
  if page_cache then
    return page_cache
  end
  local src = debug.getinfo(1, "S").source:gsub("^@", "")
  local dir = vim.fs.joinpath(vim.fs.dirname(vim.fs.normalize(src)), "page")
  local function read(name)
    local f = assert(io.open(vim.fs.joinpath(dir, name), "rb"))
    local s = f:read("*a")
    f:close()
    return s
  end
  local libs = require("config.gitlab_preview.libs")
  -- CSP: 読み込みを許すのは、自分のページと libs.lua に書いた版のファイルだけ
  local scripts, styles, fonts = { "'self'" }, { "'self'", "'unsafe-inline'" }, { "data:" }
  for _, lib in pairs(libs) do
    scripts[#scripts + 1] = lib.url
    if lib.css then
      styles[#styles + 1] = lib.css
    end
    if lib.fonts then
      fonts[#fonts + 1] = lib.fonts
    end
  end
  local csp = table.concat({
    "default-src 'none'",
    "script-src " .. table.concat(scripts, " "),
    -- mermaid は SVG の中に <style> を、KaTeX は style 属性を書くので 'unsafe-inline' が要る
    "style-src " .. table.concat(styles, " "),
    "font-src " .. table.concat(fonts, " "),
    -- 画像と動画は、GitLab のアップロードや外部のバッジなど、どこからでも読む
    "img-src * data: blob:",
    "media-src *",
    "connect-src 'self'",
    "base-uri 'none'",
    "form-action 'none'",
    "frame-ancestors 'none'",
  }, "; ")
  -- ライブラリの表はページに JSON で埋め込む (実行されない <script type="application/json">)
  local libs_json = vim.json.encode(libs):gsub("<", "\\u003c")
  page_cache = {
    html = (read("index.html"):gsub("{{LIBS}}", function()
      return libs_json
    end)),
    js = read("preview.js"),
    css = read("preview.css"),
    csp = csp,
  }
  return page_cache
end

local function is_target(buf)
  return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "markdown" and vim.bo[buf].buftype == ""
end

-- バッファの文脈 (ルート・送り先・project・表示名)。git を呼ぶので、ディレクトリごとに覚えておく
local function context_for(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  local dir = name ~= "" and vim.fs.dirname(name) or vim.uv.cwd()
  local ctx = state.ctx_cache[dir]
  if not ctx then
    ctx = gitlab.context(dir)
    state.ctx_cache[dir] = ctx
  end
  local real_dir = vim.uv.fs_realpath(dir) or dir
  local reldir = gitlab.relpath(ctx.root, real_dir) or ""
  local file = name ~= "" and vim.fs.basename(name) or "[No Name]"
  return {
    root = ctx.root,
    api = ctx.api,
    project = ctx.project,
    dir = reldir == "" and "" or reldir .. "/", -- .md のディレクトリのルートからの相対 (ページが相対リンクを解決する)
    file = (reldir == "" and "" or reldir .. "/") .. file,
    base_ctx = ctx,
  }
end

-- GitLab に送ってよいか。送れないときは、その理由 (バナーに出す) を返す
local function blocked()
  local token = vim.env.GITLAB_TOKEN
  if not token or vim.trim(token) == "" then
    return "GITLAB_TOKEN が未設定"
  end
  if vim.fn.executable("curl") == 0 then
    return "curl が見つからない"
  end
  if state.api_off then
    return state.api_off
  end
  if state.retry_at and vim.uv.now() < state.retry_at then
    return state.retry_reason
  end
end

local function gitlab_info(ctx)
  return { origin = ctx.api.origin, host = ctx.api.host, path = ctx.api.path, project = ctx.project }
end

-- 結果をバッファごとに覚え、追従中のバッファのものならページに送る
local function publish(buf, tick, payload)
  state.cache[buf] = { tick = tick, payload = payload }
  if buf == state.buf then
    state.root = payload.root -- 画像などのファイルは、このルートの内側から返す
    server.broadcast("render", payload.data)
  end
end

local function fallback(ctx, text, reason)
  return {
    root = ctx.root,
    data = {
      mode = "fallback",
      file = ctx.file,
      dir = ctx.dir,
      markdown = text,
      reason = reason,
    },
  }
end

local render_now

local function schedule_render(delay)
  if not state then
    return
  end
  state.timers.render:stop()
  state.timers.render:start(delay, 0, vim.schedule_wrap(render_now))
end

render_now = function()
  if not state then
    return
  end
  local buf = state.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local cached = state.cache[buf]
  if cached and cached.tick == tick then
    -- 変わっていない (別のバッファから戻ってきた) ときは、前回の結果を送り直すだけ
    if state.req and state.req.buf ~= buf then
      state.req.cancel()
      state.req = nil
    end
    state.root = cached.payload.root
    server.broadcast("render", cached.payload.data)
    return
  end
  if state.req then
    if state.req.buf == buf then
      state.dirty = true -- 送信中にまた変わった。終わってからもう 1 度だけ送る
      return
    end
    state.req.cancel() -- 別のバッファのものは要らない
    state.req = nil
  end

  local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n"
  local ctx = context_for(buf)
  local reason = blocked()
  if reason then
    return publish(buf, tick, fallback(ctx, text, reason))
  end

  state.req_id = state.req_id + 1
  local id = state.req_id
  state.dirty = false
  local req = { id = id, buf = buf }
  state.req = req
  req.cancel = gitlab.render(text, ctx, function(r)
    if not state or state.req ~= req then
      return -- 止めた・別の依頼に置き換わった
    end
    state.req = nil
    if r.project_dropped then
      ctx.base_ctx.project = nil -- 読めない project はこのディレクトリでは送らない
      ctx.project = nil
    end
    local payload
    if r.kind == "ok" then
      state.retry_at = nil
      payload = {
        root = ctx.root,
        data = {
          mode = "api",
          file = ctx.file,
          dir = ctx.dir,
          html = r.html,
          gitlab = gitlab_info(ctx),
        },
      }
    else
      local why
      if r.kind == "auth" then
        why = ("トークンが拒否された (HTTP %d)。read_api のトークンと GITLAB_HOST を確かめて :GitLabPreview"):format(
          r.status
        )
        state.api_off = why
      elseif r.kind == "notfound" then
        why = "GitLab の API が見つからない (HTTP 404)。GITLAB_HOST を確かめて :GitLabPreview"
        state.api_off = why
      elseif r.kind == "network" then
        why = ("GitLab に接続できない (%s)"):format(r.reason or "")
        state.retry_at, state.retry_reason = vim.uv.now() + M.config.retry_ms, why
      elseif r.kind == "ratelimit" then
        why = "GitLab の回数制限 (HTTP 429)。しばらく待ってから送り直す"
        state.retry_at, state.retry_reason = vim.uv.now() + M.config.retry_ms, why
      else
        why = ("GitLab の応答を読めない (HTTP %s)"):format(r.status or "?")
      end
      payload = fallback(ctx, text, why)
    end
    publish(buf, tick, payload)
    if state.dirty then
      state.dirty = false
      schedule_render(0)
    end
  end)
end

local function send_scroll()
  if not state or not state.buf then
    return
  end
  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(win) ~= state.buf then
    return
  end
  local line = vim.api.nvim_win_get_cursor(win)[1]
  local top = vim.fn.line("w0", win)
  local height = vim.api.nvim_win_get_height(win)
  -- ratio: カーソルが窓の中のどの高さにあるか (0 = 上端、1 = 下端)。ページも同じ高さに合わせる
  local ratio = math.min(1, math.max(0, (line - top) / math.max(1, height - 1)))
  local lines = vim.api.nvim_buf_line_count(state.buf)
  local key = ("%d:%.3f:%d"):format(line, ratio, lines)
  if key == state.scroll_key then
    return
  end
  state.scroll_key = key
  server.broadcast("scroll", { line = line, ratio = ratio, lines = lines })
end

local function schedule_scroll()
  if state and not state.timers.scroll:is_active() then
    state.timers.scroll:start(M.config.scroll_ms, 0, vim.schedule_wrap(send_scroll))
  end
end

local function follow(buf)
  if state.buf == buf then
    return
  end
  state.buf = buf
  state.scroll_key = nil
  schedule_render(0)
  schedule_scroll()
end

local function open_browser()
  local url = server.url()
  if not url then
    return
  end
  local browser = vim.g.gitlab_preview_browser
  if browser == false then
    return notify(url)
  end
  if type(browser) == "function" then
    local ok, err = pcall(browser, url)
    if not ok then
      notify(("ブラウザを開けない (%s)。%s"):format(err, url), vim.log.levels.WARN)
    end
    return
  end
  local opt = nil
  if type(browser) == "string" then
    opt = { cmd = { browser } }
  elseif type(browser) == "table" then
    opt = { cmd = vim.deepcopy(browser) }
  end
  local _, err = vim.ui.open(url, opt)
  if err then
    notify(("ブラウザを開けない (%s)。%s"):format(err, url), vim.log.levels.WARN)
  end
end

local function create_autocmds()
  local group = vim.api.nvim_create_augroup("user_gitlab_preview", { clear = true })
  state.group = group
  -- 表示中の markdown のバッファに追従する (ほかの種類のバッファに移っても、ページはそのまま)
  vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
    group = group,
    callback = function(ev)
      if ev.buf == vim.api.nvim_get_current_buf() and is_target(ev.buf) then
        follow(ev.buf)
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
    group = group,
    callback = function(ev)
      if ev.buf == state.buf then
        schedule_render(M.config.debounce_ms)
      end
    end,
  })
  -- 名前を変えた (:saveas など) ときは、ルートと project を求め直す
  vim.api.nvim_create_autocmd("BufFilePost", {
    group = group,
    callback = function(ev)
      state.cache[ev.buf] = nil
      state.ctx_cache = {}
      if ev.buf == state.buf then
        schedule_render(0)
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "WinScrolled" }, {
    group = group,
    callback = schedule_scroll,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(ev)
      state.cache[ev.buf] = nil
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      M.stop("exit")
    end,
  })
end

--- プレビューを始める。動いていれば、GitLab への送信の停止を解いて描き直し、ブラウザを開き直す
--- (トークンや GITLAB_HOST を直した後は、これで送り直す)。
function M.start()
  local buf = vim.api.nvim_get_current_buf()
  if not is_target(buf) then
    return notify("Markdown のバッファで実行する", vim.log.levels.WARN)
  end
  if state then
    state.api_off, state.retry_at, state.retry_reason = nil, nil, nil
    state.ctx_cache, state.cache = {}, {}
    state.buf = buf
    schedule_render(0)
    open_browser()
    return
  end

  local ok_page, page = pcall(load_page)
  if not ok_page then
    return notify("ページのファイルを読めない: " .. tostring(page), vim.log.levels.ERROR)
  end
  local ok, err = server.start({
    page = { html = page.html, js = page.js, css = page.css },
    csp = page.csp,
    root = function()
      return state and state.root
    end,
  })
  if not ok then
    return notify("サーバーを起動できない: " .. tostring(err), vim.log.levels.ERROR)
  end
  state = {
    buf = nil,
    req_id = 0,
    req = nil,
    dirty = false,
    cache = {},
    ctx_cache = {},
    timers = { render = assert(vim.uv.new_timer()), scroll = assert(vim.uv.new_timer()) },
  }
  create_autocmds()
  follow(buf)

  local url = server.url()
  -- このセッションで前に開いたのと同じ URL (同じポートと token) なら、開いたままのタブが
  -- 再接続してくる (EventSource は 1 秒ごとにつなぎ直す)。少し待ち、来なければ開く
  if url == last_url then
    vim.defer_fn(function()
      if state and server.client_count() == 0 then
        open_browser()
      end
    end, M.config.reconnect_wait_ms)
  else
    open_browser()
  end
  last_url = url
end

--- プレビューを止める。ページには止めたことを伝える ("exit" は Neovim の終了)。
---@param reason? "stop"|"exit"
function M.stop(reason)
  if not state then
    return
  end
  local s = state
  state = nil
  if s.req then
    s.req.cancel()
  end
  for _, t in pairs(s.timers) do
    t:stop()
    t:close()
  end
  pcall(vim.api.nvim_del_augroup_by_id, s.group)
  local clients = server.close(reason or "stop")
  if reason == "exit" then
    -- 終了する前に、タブへの「終了した」を書き終える (短く待つだけ。届かなくてもタブは切断を表示する)
    vim.wait(200, function()
      return next(clients) == nil
    end, 10)
  end
end

function M.toggle()
  if state then
    M.stop()
  else
    M.start()
  end
end

--- ブラウザでページを開き直す
function M.open()
  if state then
    open_browser()
  end
end

---@return string?
function M.url()
  return state and server.url() or nil
end

function M.is_running()
  return state ~= nil
end

return M
