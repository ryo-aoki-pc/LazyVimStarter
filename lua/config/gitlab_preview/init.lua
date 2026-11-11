-- md-preview との橋渡し。描画・HTTP・公式スタイルの処理は mdpreview 実行ファイルに任せる。
-- require だけでは起動せず、Neovim につき1つの子プロセスを標準入出力の取り決めの版1で使う。
-- stop は休止、VimLeavePre は標準入力を閉じる。設定と配線は lua/plugins/gitlab-preview.lua。
local M = {}
local uv = vim.uv or vim.loop
M.config = { debounce_ms = 300, scroll_ms = 80, reconnect_wait_ms = 1500, ready_timeout_ms = 10000 }
local app, install_job
local shutdown_group
local missing_warned, leaving = false, false
local send_doc, send_scroll, spawn_app, terminate

local function notify(message, level)
  vim.notify("GitLab プレビュー: " .. message, level or vim.log.levels.INFO)
end

local function absolute_path(path)
  return vim.fs.normalize(vim.fn.fnamemodify(vim.fs.normalize(path), ":p"))
end

local function command()
  local configured = vim.g.gitlab_preview_command
  if type(configured) == "string" and configured ~= "" then
    return { absolute_path(configured) }
  elseif type(configured) == "table" and vim.islist(configured) and #configured > 0 then
    local valid = true
    for _, value in ipairs(configured) do
      if type(value) ~= "string" or value == "" then
        valid = false
        break
      end
    end
    if valid then
      return vim.deepcopy(configured)
    end
  end

  local windows = vim.fn.has("win32") == 1
  local executable = vim.fn.exepath("mdpreview")
  if executable ~= "" and (not windows or executable:lower():match("%.exe$")) then
    return { absolute_path(executable) }
  end

  local home = uv.os_homedir() or vim.fn.expand("~")
  local fallback = vim.fs.joinpath(home, ".local", "bin", windows and "mdpreview.exe" or "mdpreview")
  local stat = uv.fs_stat(fallback)
  if stat and stat.type == "file" then
    return { absolute_path(fallback) }
  end
  if not missing_warned then
    missing_warned = true
    notify(
      "md-preview が導入されていません。md-preview の docs/install.md の手順で導入してください: "
        .. "https://github.com/ryo-aoki-pc/md-preview/blob/main/docs/install.md",
      vim.log.levels.WARN
    )
  end
end

local function is_target(buf)
  return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "markdown" and vim.bo[buf].buftype == ""
end

local function close_timer(timer)
  if timer and not timer:is_closing() then
    timer:stop()
    timer:close()
  end
end

local function deactivate(s)
  s.active = false
  for _, timer in pairs(s.timers or {}) do
    close_timer(timer)
  end
  s.timers = {}
  if s.group then
    pcall(vim.api.nvim_del_augroup_by_id, s.group)
    s.group = nil
  end
  s.last_buf, s.last_tick, s.scroll_key, s.open_mode = nil, nil, nil, nil
end

local function open_browser(s)
  if app ~= s or not s.url then
    return
  end
  local browser = vim.g.gitlab_preview_browser
  if browser == false then
    return notify(s.url)
  end
  if type(browser) == "function" then
    local ok, err = pcall(browser, s.url)
    if not ok then
      notify(("ブラウザを開けない (%s)。%s"):format(err, s.url), vim.log.levels.WARN)
    end
    return
  end
  local opt
  if type(browser) == "string" then
    opt = { cmd = { browser } }
  elseif type(browser) == "table" then
    opt = { cmd = vim.deepcopy(browser) }
  end
  local _, err = vim.ui.open(s.url, opt)
  if err then
    notify(("ブラウザを開けない (%s)。%s"):format(err, s.url), vim.log.levels.WARN)
  end
end

local function send(s, value)
  if app ~= s or s.exited or not s.proc then
    return false
  end
  local ok, err = pcall(function()
    s.proc:write(vim.json.encode(value) .. "\n")
  end)
  if not ok then
    notify("アプリへ送れません: " .. tostring(err), vim.log.levels.ERROR)
    terminate(s)
  end
  return ok
end

local function schedule_doc(s, delay)
  if app ~= s or not s.active then
    return
  end
  s.timers.doc:stop()
  s.timers.doc:start(
    delay,
    0,
    vim.schedule_wrap(function()
      send_doc(s)
    end)
  )
end

local function schedule_scroll(s)
  if app == s and s.active and not s.timers.scroll:is_active() then
    s.timers.scroll:start(
      M.config.scroll_ms,
      0,
      vim.schedule_wrap(function()
        send_scroll(s)
      end)
    )
  end
end

send_doc = function(s, force)
  if app ~= s or not s.active or not s.ready or not s.buf or not is_target(s.buf) then
    return
  end
  local buf = s.buf
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  if not force and s.last_buf == buf and s.last_tick == tick then
    return
  end
  local name = vim.api.nvim_buf_get_name(buf)
  local file = name ~= "" and vim.fs.normalize(vim.fn.fnamemodify(name, ":p")) or vim.NIL
  if
    send(s, {
      type = "doc",
      buf = buf,
      path = file,
      name = name ~= "" and vim.fs.basename(name) or "[No Name]",
      text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n",
      rev = tick,
    })
  then
    s.last_buf, s.last_tick = buf, tick
    schedule_scroll(s)
  end
end

send_scroll = function(s)
  if app ~= s or not s.active or not s.ready or not s.buf or not vim.api.nvim_buf_is_valid(s.buf) then
    return
  end
  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(win) ~= s.buf then
    return
  end
  local line = vim.api.nvim_win_get_cursor(win)[1]
  local top = vim.fn.line("w0", win)
  local height = vim.api.nvim_win_get_height(win)
  local ratio = math.min(1, math.max(0, (line - top) / math.max(1, height - 1)))
  local lines = vim.api.nvim_buf_line_count(s.buf)
  local key = ("%d:%.3f:%d"):format(line, ratio, lines)
  if key ~= s.scroll_key and send(s, { type = "scroll", line = line, ratio = ratio, lines = lines }) then
    s.scroll_key = key
  end
end

local function follow(s, buf)
  if s.buf ~= buf then
    s.buf, s.last_buf, s.last_tick, s.scroll_key = buf, nil, nil, nil
    schedule_doc(s, 0)
    schedule_scroll(s)
  end
end

local function activate(s, buf)
  s.active = true
  s.timers = { doc = assert(uv.new_timer()), scroll = assert(uv.new_timer()) }
  s.group = vim.api.nvim_create_augroup("user_gitlab_preview", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
    group = s.group,
    callback = function(ev)
      if app == s and s.active and ev.buf == vim.api.nvim_get_current_buf() and is_target(ev.buf) then
        follow(s, ev.buf)
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
    group = s.group,
    callback = function(ev)
      if app == s and s.active and ev.buf == s.buf then
        schedule_doc(s, M.config.debounce_ms)
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufFilePost", {
    group = s.group,
    callback = function(ev)
      if app == s and s.active and ev.buf == s.buf then
        s.last_buf, s.last_tick = nil, nil
        schedule_doc(s, 0)
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "WinScrolled" }, {
    group = s.group,
    callback = function()
      schedule_scroll(s)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = s.group,
    callback = function(ev)
      if s.buf == ev.buf then
        s.buf, s.last_buf, s.last_tick = nil, nil, nil
      end
    end,
  })
  s.buf = nil
  follow(s, buf)
end

local function reconnect(s)
  if s.clients ~= 0 then
    return
  end
  close_timer(s.timers.reconnect)
  s.timers.reconnect = assert(uv.new_timer())
  s.timers.reconnect:start(
    M.config.reconnect_wait_ms,
    0,
    vim.schedule_wrap(function()
      if app == s and s.active and s.clients == 0 then
        open_browser(s)
      end
    end)
  )
end

local function jump(s, message)
  if type(message.line) ~= "number" or message.line ~= message.line then
    return
  end
  local buf
  if message.path == vim.NIL then
    buf = s.buf
  elseif type(message.path) == "string" then
    local target = vim.fs.normalize(vim.fn.fnamemodify(message.path, ":p"))
    local windows = vim.fn.has("win32") == 1
    for _, candidate in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(candidate)
      if name ~= "" then
        name = vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
        if (windows and name:lower() == target:lower()) or (not windows and name == target) then
          buf = candidate
          break
        end
      end
    end
  end
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return -- どのバッファにも無いファイルを開かない。
  end
  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(win) ~= buf then
    for _, candidate in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(candidate) == buf then
        win = candidate
        break
      end
    end
    vim.api.nvim_set_current_win(win)
    if vim.api.nvim_win_get_buf(win) ~= buf then
      vim.api.nvim_win_set_buf(win, buf)
    end
  end
  local line = math.min(vim.api.nvim_buf_line_count(buf), math.max(1, math.floor(message.line)))
  vim.api.nvim_win_set_cursor(win, { line, 0 })
  schedule_scroll(s)
end

local function last_line(value)
  return vim.trim(value or ""):match("([^\r\n]+)$") or ""
end

local function is_integer(value)
  return type(value) == "number" and value % 1 == 0
end

local function apply_edit(s, value)
  if not s.ready or not s.active or not s.edit then
    return false, "プレビューからの編集を受け付けていません"
  end
  local buf = s.buf
  if not buf or value.buf ~= buf or not is_target(buf) then
    return false, "Neovim で開いている文書が変わりました"
  end
  local name = vim.api.nvim_buf_get_name(buf)
  local same_path = value.path == vim.NIL and name == ""
  if type(value.path) == "string" and value.path ~= "" and name ~= "" then
    local target = vim.fs.normalize(vim.fn.fnamemodify(value.path, ":p"))
    name = vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
    same_path = name == target or (vim.fn.has("win32") == 1 and name:lower() == target:lower())
  end
  if not same_path then
    return false, "Neovim で開いている文書が変わりました"
  end
  if vim.api.nvim_buf_get_changedtick(buf) ~= value.rev then
    return false, "Neovim のバッファが変わりました。もう一度操作してください"
  end
  if not vim.bo[buf].modifiable then
    return false, "バッファを変更できません（modifiable がオフ）"
  end
  if type(value.edits) ~= "table" or not vim.islist(value.edits) or #value.edits == 0 then
    return false, "編集の内容を読めません"
  end
  local count, edits = vim.api.nvim_buf_line_count(buf), {}
  for _, item in ipairs(value.edits) do
    if
      type(item) ~= "table"
      or not is_integer(item.start)
      or not is_integer(item["end"])
      or item.start < 0
      or item.start > item["end"]
      or item["end"] > count
      or type(item.lines) ~= "table"
      or not vim.islist(item.lines)
    then
      return false, "編集の内容を読めません"
    end
    for _, line in ipairs(item.lines) do
      if type(line) ~= "string" or line:find("\n", 1, true) or line:find("\0", 1, true) then
        return false, "編集の内容を読めません"
      end
    end
    edits[#edits + 1] = item
  end
  table.sort(edits, function(a, b)
    return a.start < b.start
  end)
  for i = 2, #edits do
    -- 同じ位置への挿入も順序が曖昧なので断る。全範囲を確かめるまでは変更しない。
    if edits[i].start < edits[i - 1]["end"] or edits[i].start == edits[i - 1].start then
      return false, "編集の範囲が重なっています"
    end
  end
  -- 1つのコールバックで後ろから当て、undo を1回にまとめる。窓やモードは変えない。
  for i = #edits, 1, -1 do
    local item = edits[i]
    vim.api.nvim_buf_set_lines(buf, item.start, item["end"], true, item.lines)
  end
  return true
end

local function edit(s, value)
  if not is_integer(value.id) or value.id <= 0 then
    return
  end
  local called, ok, message = pcall(apply_edit, s, value)
  if not called then
    ok, message = false, "バッファへ編集を反映できませんでした"
  end
  send(s, { type = "edit_result", id = value.id, ok = ok, message = message })
  if ok then
    send_doc(s, true)
  end
end

local function receive(s, value)
  if app ~= s or s.exited then
    return
  end
  if type(value) ~= "table" then
    return
  end
  if value.type == "ready" and not s.ready then
    if value.protocol ~= 1 then
      notify("取り決めの版が違います。md-preview を更新してください", vim.log.levels.ERROR)
      return terminate(s)
    end
    if type(value.url) ~= "string" or value.url == "" then
      notify("アプリの URL を読めません", vim.log.levels.ERROR)
      return terminate(s)
    end
    close_timer(s.ready_timer)
    s.ready_timer = nil
    s.ready, s.url = true, value.url
    s.edit = s.edit_requested and value.edit == 1
    if s.active then
      if s.resuming then
        send(s, { type = "resume" })
      end
      send_doc(s, true)
      schedule_scroll(s)
    else
      send(s, { type = "pause" })
    end
    local mode = s.open_mode
    s.open_mode, s.resuming = nil, nil
    if mode == "now" then
      open_browser(s)
    elseif mode == "resume" then
      reconnect(s)
    end
  elseif value.type == "clients" and type(value.count) == "number" and value.count >= 0 then
    s.clients = value.count
  elseif value.type == "jump" and s.ready then
    jump(s, value)
  elseif value.type == "edit" then
    edit(s, value)
  elseif value.type == "error" and type(value.message) == "string" then
    if value.message ~= s.last_error then
      s.last_error = value.message
      notify(value.message, value.fatal and vim.log.levels.ERROR or vim.log.levels.WARN)
    end
    if value.fatal then
      terminate(s)
    end
  end
end

local function stdout(s, data)
  if app ~= s then
    return
  end
  s.output = s.output .. data
  while true do
    local at = s.output:find("\n", 1, true)
    if not at then
      break
    end
    local line = s.output:sub(1, at - 1):gsub("\r$", "")
    s.output = s.output:sub(at + 1)
    if line ~= "" then
      local ok, value = pcall(vim.json.decode, line)
      if ok then
        receive(s, value)
      elseif s.last_error ~= "アプリの JSON の行を読めません" then
        s.last_error = "アプリの JSON の行を読めません"
        notify(s.last_error, vim.log.levels.WARN)
      end
    end
  end
end

local function stderr(s, data)
  if app ~= s then
    return
  end
  s.stderr = s.stderr .. data
  local lines = vim.split(s.stderr, "\n", { plain = true })
  while #lines > 11 do
    table.remove(lines, 1)
  end
  s.stderr = table.concat(lines, "\n"):sub(-8192)
end

terminate = function(s)
  s.intentional = true
  deactivate(s)
  close_timer(s.ready_timer)
  s.ready_timer = nil
  if s.proc and not s.exited then
    pcall(s.proc.write, s.proc, nil)
    local ok, result = pcall(s.proc.wait, s.proc, 200)
    if not ok or not result or result.code == 124 then
      pcall(s.proc.kill, s.proc, 9)
      pcall(s.proc.wait, s.proc, 200)
    end
  end
  if app == s then
    app = nil
  end
end

local function ensure_shutdown()
  if not shutdown_group then
    shutdown_group = vim.api.nvim_create_augroup("user_gitlab_preview_process", { clear = true })
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = shutdown_group,
      callback = function()
        leaving = true
        if app then
          terminate(app)
        end
        if install_job and install_job.proc then
          pcall(install_job.proc.kill, install_job.proc, 9)
        end
      end,
    })
  end
end

spawn_app = function(buf, active, open_mode)
  local argv = command()
  if not argv then
    return
  end
  argv[#argv + 1] = "--stdio"
  local s = { buf = buf, active = false, clients = 0, timers = {}, output = "", stderr = "", open_mode = open_mode }
  app = s
  if active then
    activate(s, buf)
  end
  ensure_shutdown()
  -- vim.system のコールバックは fast context。状態のフラグ以外は schedule の中で触る。
  local ok, proc = pcall(vim.system, argv, {
    stdin = true,
    text = true,
    stdout = function(_, data)
      if data then
        vim.schedule(function()
          stdout(s, data)
        end)
      end
    end,
    stderr = function(_, data)
      if data then
        vim.schedule(function()
          stderr(s, data)
        end)
      end
    end,
  }, function(result)
    s.exited = true
    vim.schedule(function()
      if app ~= s then
        return
      end
      deactivate(s)
      close_timer(s.ready_timer)
      app = nil
      if not s.intentional and not leaving then
        local tail = not s.ready and last_line(s.stderr) or ""
        notify(
          "プレビューのアプリが終了しました" .. (tail ~= "" and ": " .. tail or ""),
          vim.log.levels.ERROR
        )
      end
    end)
  end)
  if not ok then
    deactivate(s)
    app = nil
    notify("アプリを起動できません: " .. tostring(proc), vim.log.levels.ERROR)
    return
  end
  s.proc = proc
  s.ready_timer = assert(uv.new_timer())
  s.ready_timer:start(
    M.config.ready_timeout_ms,
    0,
    vim.schedule_wrap(function()
      if app == s and not s.ready then
        local tail = last_line(s.stderr)
        notify("アプリの起動が時間切れです" .. (tail ~= "" and ": " .. tail or ""), vim.log.levels.ERROR)
        terminate(s)
      end
    end)
  )
  local appearance = vim.g.gitlab_preview_appearance
  appearance = type(appearance) == "table" and appearance or {}
  local theme, width = appearance.theme, appearance.width
  s.edit_requested = vim.g.gitlab_preview_edit ~= false
  send(s, {
    type = "hello",
    protocol = 1,
    edit = s.edit_requested and 1 or nil,
    appearance = {
      theme = (theme == "light" or theme == "dark") and theme or "system",
      width = width == "fixed" and width or "fluid",
    },
  })
end

function M.start()
  if leaving then
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  if not is_target(buf) then
    return notify("Markdown のバッファで実行する", vim.log.levels.WARN)
  end
  if not app then
    return spawn_app(buf, true, "now")
  end
  local s = app
  if s.active then
    follow(s, buf)
    send_doc(s, true)
    if s.ready then
      open_browser(s)
    else
      s.open_mode = "now"
    end
  else
    activate(s, buf)
    if s.ready then
      send(s, { type = "resume" })
      send_doc(s, true)
      reconnect(s)
    else
      s.resuming, s.open_mode = true, "resume"
    end
  end
end

function M.stop()
  if app and app.active then
    if app.ready then
      send(app, { type = "pause" })
    end
    if app then
      deactivate(app)
    end
  end
end

function M.toggle()
  if M.is_running() then
    M.stop()
  else
    M.start()
  end
end

function M.open()
  if app and app.active then
    open_browser(app)
  end
end

function M.url()
  return app and app.active and app.url or nil
end

function M.is_running()
  return app ~= nil and app.active
end

function M.install()
  if install_job then
    return notify("公式スタイルの導入は進行中です")
  end
  local argv = command()
  if not argv then
    return
  end
  argv[#argv + 1] = "install-style"
  ensure_shutdown()
  local job = {}
  install_job = job
  local ok, proc = pcall(vim.system, argv, { text = true }, function(result)
    vim.schedule(function()
      if install_job ~= job then
        return
      end
      install_job = nil
      if leaving then
        return
      end
      if result.code ~= 0 then
        local reason = last_line(result.stderr)
        return notify(
          reason ~= "" and reason or "公式スタイルの導入に失敗しました",
          vim.log.levels.ERROR
        )
      end
      local message = last_line(result.stdout)
      notify(message ~= "" and message or "公式スタイルを導入しました")
      if app then
        local buf, active = app.buf, app.active
        terminate(app)
        -- 休止状態は保ち、URL が変わるので新しいページを開く。
        spawn_app(buf, active, "now")
      end
    end)
  end)
  if ok then
    job.proc = proc
  else
    install_job = nil
    notify("導入のアプリを起動できません: " .. tostring(proc), vim.log.levels.ERROR)
  end
end

return M
