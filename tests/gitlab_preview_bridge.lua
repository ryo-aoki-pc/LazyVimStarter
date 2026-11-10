-- 設定・通信・ブラウザ・本物の md-preview を使わず、子プロセスとの配線を確かめる。
local source = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(source)))
vim.opt.runtimepath:prepend(root)
if vim.fn.executable("node") == 0 then
  print("GitLab プレビューの橋渡し: Node.js が無いため未実施 (成功0件・skip1件)")
  return
end
local uv = vim.uv or vim.loop
local sandbox = vim.fs.joinpath(root, ".tests", "gitlab-preview-bridge-" .. uv.os_getpid())
vim.fn.mkdir(sandbox, "p")
local log = vim.fs.joinpath(sandbox, "events.jsonl")
local original = {
  notify = vim.notify,
  open = vim.ui.open,
  system = vim.system,
  exepath = vim.fn.exepath,
  has = vim.fn.has,
  homedir = uv.os_homedir,
}
local saved_dir = vim.env.MD_PREVIEW_BRIDGE_TEST_DIR
vim.env.MD_PREVIEW_BRIDGE_TEST_DIR = sandbox
local fake_app = vim.fs.joinpath(root, "tests", "gitlab_preview_bridge", "fake-app.mjs")
local fake_command = { "node", fake_app }
vim.g.gitlab_preview_command = vim.deepcopy(fake_command)
local home = vim.fs.joinpath(sandbox, "home")
uv.os_homedir = function()
  return home
end
vim.fn.exepath = function(name)
  return name == "mdpreview" and "" or original.exepath(name)
end
local warnings, opened, commands = {}, {}, {}
vim.notify = function(message, level)
  assert(not vim.in_fast_event(), "知らせを fast context から出さない")
  warnings[#warnings + 1] = { message = message, level = level }
end
vim.ui.open = function(url, options)
  assert(not vim.in_fast_event(), "ブラウザを fast context から開かない")
  opened[#opened + 1] = { url = url, options = options }
end
local function browser(url)
  assert(not vim.in_fast_event(), "ブラウザの関数も通常の文脈で呼ぶ")
  opened[#opened + 1] = { url = url, callback = true }
end
vim.g.gitlab_preview_browser = browser
vim.g.gitlab_preview_appearance = { theme = "dark", width = "fixed" }
local function config(value)
  vim.fn.writefile({ vim.json.encode(value or {}) }, vim.fs.joinpath(sandbox, "config.json"))
end
local function events(kind)
  local found = {}
  if vim.fn.filereadable(log) == 1 then
    for _, line in ipairs(vim.fn.readfile(log)) do
      local ok, value = pcall(vim.json.decode, line)
      if ok and (not kind or value.kind == kind) then
        found[#found + 1] = value
      end
    end
  end
  return found
end
local function messages(kind)
  local found = {}
  for _, event in ipairs(events("input")) do
    if event.message and (not kind or event.message.type == kind) then
      found[#found + 1] = event
    end
  end
  return found
end
local function last(kind)
  local values = messages(kind)
  return values[#values] and values[#values].message
end
local function process_count(mode)
  local count = 0
  for _, event in ipairs(events("start")) do
    if event.mode == (mode or "--stdio") then
      count = count + 1
    end
  end
  return count
end
local function pid()
  local value
  for _, event in ipairs(events("start")) do
    if event.mode == "--stdio" then
      value = event.pid
    end
  end
  return value
end
local function alive(value)
  return value and uv.kill(value, 0) ~= nil
end
local function wait(message, condition, timeout)
  assert(vim.wait(timeout or 3000, condition, 5), message)
end
local function settle(ms)
  vim.wait(ms or 60, function()
    return false
  end, 5)
end
local function issue(command, no_wait)
  command.pid = pid()
  commands[#commands + 1] = command
  vim.fn.writefile({ vim.json.encode(commands) }, vim.fs.joinpath(sandbox, "commands.json"))
  if not no_wait then
    local index = #commands
    wait("偽アプリの指示を処理", function()
      for _, event in ipairs(events("command")) do
        if event.pid == command.pid and event.index == index then
          return true
        end
      end
    end)
    settle(10)
  end
end
local function emit(value)
  issue({ kind = "emit", value = value })
end
local function buffer(name, lines, ft)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  if name then
    vim.api.nvim_buf_set_name(buf, vim.fs.joinpath(sandbox, name))
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or { "# 文書" })
  vim.bo[buf].filetype = ft or "markdown"
  return buf
end
local function trigger(event, buf)
  vim.api.nvim_exec_autocmds(event, { buffer = buf or vim.api.nvim_get_current_buf() })
end
local function ready(preview)
  wait("ready の後に URL と doc を受け取る", function()
    return preview.url() ~= nil and last("doc") ~= nil
  end)
  settle(20)
end
local passed = 0
local function test(name, action)
  action()
  passed = passed + 1
  print("成功: " .. name)
end
local preview
local ok, error_message = xpcall(function()
  config({})
  test("require だけでは起動も autocmd の登録もしない", function()
    preview = require("config.gitlab_preview")
    assert(not preview.is_running() and preview.url() == nil)
    assert(process_count() == 0)
    local exists = pcall(vim.api.nvim_get_autocmds, { group = "user_gitlab_preview_process" })
    assert(not exists)
    assert(preview.config.debounce_ms == 300 and preview.config.scroll_ms == 80)
    assert(preview.config.reconnect_wait_ms == 1500 and preview.config.ready_timeout_ms == 10000)
    preview.config.debounce_ms, preview.config.scroll_ms = 50, 20
    preview.config.reconnect_wait_ms, preview.config.ready_timeout_ms = 60, 1500
  end)
  test("Markdown でないバッファで開始すると警告する", function()
    preview.start()
    assert(not preview.is_running() and process_count() == 0)
    assert(warnings[#warnings].level == vim.log.levels.WARN)
  end)
  test("Markdown でも通常でない buftype は対象にしない", function()
    vim.bo.filetype, vim.bo.buftype = "markdown", "nofile"
    preview.start()
    assert(not preview.is_running() and warnings[#warnings].level == vim.log.levels.WARN)
    vim.bo.buftype, vim.bo.filetype = "", ""
  end)
  local lines = {}
  for i = 1, 100 do
    lines[i] = "行 " .. i
  end
  local a = buffer("文書 A.md", lines)
  local function select_command(configured, executable, windows, action)
    local captured = {}
    vim.g.gitlab_preview_command = configured
    vim.fn.exepath = function(name)
      return name == "mdpreview" and executable or original.exepath(name)
    end
    vim.fn.has = function(name)
      return name == "win32" and (windows and 1 or 0) or original.has(name)
    end
    vim.system = function(argv)
      captured[#captured + 1] = argv
      error("探索だけを確かめ、子プロセスは起こさない")
    end
    action(captured)
    vim.system, vim.fn.has = original.system, original.has
    vim.fn.exepath = function(name)
      return name == "mdpreview" and "" or original.exepath(name)
    end
    vim.g.gitlab_preview_command = vim.deepcopy(fake_command)
  end
  test("文字列の設定を正規化した絶対パスにし、PATH より優先する", function()
    local relative = "tests/../tests/gitlab_preview_bridge/試験用アプリ"
    select_command(relative, vim.fs.joinpath(sandbox, "path-mdpreview.exe"), true, function(captured)
      preview.start()
      assert(vim.deep_equal(captured[1], { vim.fs.normalize(vim.fn.fnamemodify(relative, ":p")), "--stdio" }))
      assert(vim.g.gitlab_preview_command == relative)
    end)
  end)
  test("並びの設定をそのまま使い、起動ごとに引数の並びを新しく作る", function()
    select_command(fake_command, "", false, function(captured)
      preview.start()
      preview.install()
      assert(vim.deep_equal(captured[1], { "node", fake_app, "--stdio" }))
      assert(vim.deep_equal(captured[2], { "node", fake_app, "install-style" }))
      assert(captured[1] ~= captured[2] and vim.deep_equal(vim.g.gitlab_preview_command, fake_command))
    end)
  end)
  test("未設定・空の値・誤った型は無視して PATH を探す", function()
    local executable = vim.fs.joinpath(sandbox, "PATH の mdpreview.exe")
    local invalid = { "", {}, false, 42, { program = "node" }, { "node", "" }, { "node", 42 } }
    for i = 0, #invalid do
      select_command(invalid[i], executable, true, function(captured)
        preview.start()
        assert(vim.deep_equal(captured[1], { executable, "--stdio" }), vim.inspect(invalid[i]))
      end)
    end
  end)
  test("Windows の PATH は大文字の EXE も使い、ほかの OS は拡張子を求めない", function()
    for _, item in ipairs({ { true, "mdpreview.EXE" }, { false, "mdpreview" } }) do
      local executable = vim.fs.joinpath(sandbox, item[2])
      select_command(nil, executable, item[1], function(captured)
        preview.install()
        assert(vim.deep_equal(captured[1], { executable, "install-style" }))
      end)
    end
  end)
  local bin = vim.fs.joinpath(home, ".local", "bin")
  test("PATH に無ければ試験用ホームの .local/bin のファイルを使う", function()
    vim.fn.mkdir(bin, "p")
    for _, windows in ipairs({ false, true }) do
      local executable = vim.fs.joinpath(bin, windows and "mdpreview.exe" or "mdpreview")
      vim.fn.writefile({ "探索の試験用" }, executable)
      select_command(nil, "", windows, function(captured)
        preview.start()
        assert(vim.deep_equal(captured[1], { executable, "--stdio" }))
      end)
    end
  end)
  test("Windows の PATH の cmd・bat・ps1 は使わず、決まった場所へ進む", function()
    local executable = vim.fs.joinpath(bin, "mdpreview.exe")
    for _, extension in ipairs({ "cmd", "CMD", "bat", "ps1" }) do
      select_command(nil, vim.fs.joinpath(sandbox, "mdpreview." .. extension), true, function(captured)
        preview.start()
        assert(vim.deep_equal(captured[1], { executable, "--stdio" }))
      end)
    end
  end)
  test("PATH で見つかれば決まった場所のファイルより優先する", function()
    local executable = vim.fs.joinpath(sandbox, "優先する mdpreview.exe")
    select_command(nil, executable, true, function(captured)
      preview.start()
      assert(vim.deep_equal(captured[1], { executable, "--stdio" }))
    end)
    vim.fn.delete(vim.fs.joinpath(bin, "mdpreview"))
    vim.fn.delete(vim.fs.joinpath(bin, "mdpreview.exe"))
  end)
  test("hello と appearance を送り、ready の URL でブラウザの関数を呼ぶ", function()
    preview.start()
    ready(preview)
    assert(process_count() == 1)
    local hello = assert(last("hello"))
    assert(hello.protocol == 1 and hello.appearance.theme == "dark" and hello.appearance.width == "fixed")
    assert(opened[#opened].callback and opened[#opened].url == preview.url())
  end)
  test("doc の絶対パス・名前・本文・changedtick を送る", function()
    local doc = assert(last("doc"))
    assert(doc.path == vim.fs.normalize(vim.api.nvim_buf_get_name(a)))
    assert(doc.name == "文書 A.md" and doc.text == table.concat(lines, "\n") .. "\n")
    assert(doc.rev == vim.api.nvim_buf_get_changedtick(a))
  end)
  test("本文の連続する変更を1回にまとめ、同じ changedtick は再送しない", function()
    local before = #messages("doc")
    for i = 1, 3 do
      vim.api.nvim_buf_set_lines(a, 0, 1, false, { "変更 " .. i })
      trigger(({ "TextChanged", "TextChangedI", "TextChangedP" })[i], a)
    end
    settle(20)
    assert(#messages("doc") == before)
    wait("変更を1回送る", function()
      return #messages("doc") == before + 1
    end)
    trigger("TextChanged", a)
    settle(90)
    assert(#messages("doc") == before + 1 and last("doc").text:find("変更 3", 1, true))
  end)
  test("カーソルとスクロールを間引き、同じ値は再送しない", function()
    settle(40)
    local before = #messages("scroll")
    vim.api.nvim_win_set_cursor(0, { 5, 0 })
    trigger("CursorMoved")
    vim.api.nvim_win_set_cursor(0, { 8, 0 })
    trigger("CursorMovedI")
    trigger("WinScrolled")
    wait("scroll を1回送る", function()
      return #messages("scroll") == before + 1
    end)
    local scroll = last("scroll")
    local ratio = math.min(1, math.max(0, (8 - vim.fn.line("w0")) / math.max(1, vim.api.nvim_win_get_height(0) - 1)))
    assert(scroll.line == 8 and scroll.lines == 100 and scroll.ratio == ratio)
    trigger("CursorMoved")
    settle(60)
    assert(#messages("scroll") == before + 1)
  end)
  local b
  test("別のMarkdownへ追従し、ほかの種類ではページを保つ", function()
    local before = #messages("doc")
    b = buffer("文書 B.md", { "B", "二行目" })
    wait("別の文書を送る", function()
      return #messages("doc") > before and last("doc").name == "文書 B.md"
    end)
    local other = buffer("other.lua", { "local x = 1" }, "lua")
    before = #messages("doc")
    trigger("TextChanged", other)
    settle(80)
    assert(#messages("doc") == before)
    vim.api.nvim_set_current_buf(a)
    wait("前の文書へ戻ると送る", function()
      return last("doc").name == "文書 A.md"
    end)
  end)
  test("名前を変えたら changedtick が同じでも送り直す", function()
    local before, tick = #messages("doc"), vim.api.nvim_buf_get_changedtick(a)
    vim.api.nvim_buf_set_name(a, vim.fs.joinpath(sandbox, "名前を変更.md"))
    trigger("BufFilePost", a)
    wait("変更した名前を送る", function()
      return #messages("doc") > before and last("doc").name == "名前を変更.md"
    end)
    assert(last("doc").rev == tick)
  end)
  local unnamed
  test("無名のバッファは path が null、表示名は No Name になる", function()
    unnamed = buffer(nil, { "無名" })
    wait("無名の文書を送る", function()
      return last("doc").name == "[No Name]"
    end)
    assert(last("doc").path == vim.NIL)
  end)
  test("ブラウザの false・文字列・表・既定の指定を保つ", function()
    vim.g.gitlab_preview_browser = false
    local count = #opened
    preview.open()
    assert(#opened == count and warnings[#warnings].message:find(preview.url(), 1, true))
    vim.g.gitlab_preview_browser = "browser-one"
    preview.open()
    assert(opened[#opened].options.cmd[1] == "browser-one")
    vim.g.gitlab_preview_browser = { "browser-two", "--flag" }
    preview.open()
    assert(vim.deep_equal(opened[#opened].options.cmd, { "browser-two", "--flag" }))
    vim.g.gitlab_preview_browser = nil
    preview.open()
    assert(opened[#opened].options == nil)
    vim.g.gitlab_preview_browser = function()
      error("試験の失敗")
    end
    preview.open()
    assert(warnings[#warnings].level == vim.log.levels.WARN)
    vim.g.gitlab_preview_browser = browser
  end)
  test("動作中の start は本文を再送してブラウザを開き直す", function()
    local docs, count = #messages("doc"), #opened
    preview.start()
    wait("動作中に再送する", function()
      return #messages("doc") == docs + 1
    end)
    assert(#opened == count + 1 and process_count() == 1)
  end)
  test("stop は pause を送り、子プロセスを残す", function()
    local value, before = pid(), #messages("pause")
    preview.stop()
    wait("pause を受け取る", function()
      return #messages("pause") == before + 1
    end)
    assert(not preview.is_running() and preview.url() == nil and alive(value))
    local docs = #messages("doc")
    trigger("TextChanged", unnamed)
    settle(80)
    assert(#messages("doc") == docs)
  end)
  test("開いたタブがあれば resume と doc だけで再開する", function()
    emit({ type = "clients", count = 1 })
    local resumes, docs, count = #messages("resume"), #messages("doc"), #opened
    preview.start()
    wait("resume と doc を送る", function()
      return #messages("resume") == resumes + 1 and #messages("doc") == docs + 1
    end)
    settle(100)
    assert(#opened == count and process_count() == 1)
  end)
  test("タブが0なら少し待ち、戻らないときだけブラウザを開く", function()
    preview.stop()
    emit({ type = "clients", count = 0 })
    local count = #opened
    preview.start()
    settle(25)
    assert(#opened == count)
    wait("待ってからブラウザを開く", function()
      return #opened == count + 1
    end)
  end)
  test("待つ間にタブが戻ればブラウザを開き直さない", function()
    preview.stop()
    emit({ type = "clients", count = 0 })
    local count = #opened
    preview.start()
    emit({ type = "clients", count = 1 })
    settle(100)
    assert(#opened == count)
  end)
  test("jump は表示中の窓へ移り、行を文書の末尾に収める", function()
    vim.api.nvim_set_current_buf(a)
    local win = vim.api.nvim_get_current_win()
    vim.cmd("vsplit")
    vim.api.nvim_set_current_buf(b)
    emit({ type = "jump", path = vim.api.nvim_buf_get_name(a), line = 999 })
    assert(vim.api.nvim_get_current_win() == win and vim.api.nvim_get_current_buf() == a)
    assert(vim.api.nvim_win_get_cursor(win)[1] == vim.api.nvim_buf_line_count(a))
    vim.cmd("only!")
  end)
  test("隠れたバッファの jump は今の窓に出し、下限を1に収める", function()
    emit({ type = "jump", path = vim.api.nvim_buf_get_name(b), line = -10 })
    assert(vim.api.nvim_get_current_buf() == b and vim.api.nvim_win_get_cursor(0)[1] == 1)
    emit({ type = "jump", path = vim.NIL, line = 2 })
    assert(vim.api.nvim_get_current_buf() == b and vim.api.nvim_win_get_cursor(0)[1] == 2)
  end)
  test("知らない path の jump でファイルやバッファを開かない", function()
    local current, count = vim.api.nvim_get_current_buf(), #vim.api.nvim_list_bufs()
    emit({ type = "jump", path = vim.fs.joinpath(sandbox, "unknown.md"), line = 1 })
    assert(vim.api.nvim_get_current_buf() == current and #vim.api.nvim_list_bufs() == count)
  end)
  test("error は警告・誤りを分け、同じ文を連続して出さない", function()
    local before = #warnings
    emit({ type = "error", message = "日本語の警告" })
    emit({ type = "error", message = "日本語の警告" })
    assert(#warnings == before + 1 and warnings[#warnings].level == vim.log.levels.WARN)
    emit({ type = "error", fatal = true, message = "日本語の致命的な誤り" })
    assert(warnings[#warnings].level == vim.log.levels.ERROR and not preview.is_running())
  end)
  test("ready 前に休止しても子を残し、再開した時点の文書を送る", function()
    config({ readyDelay = 120 })
    local pauses, count = #messages("pause"), #opened
    preview.start()
    preview.stop()
    wait("ready の後も休止状態にする", function()
      return #messages("pause") > pauses
    end)
    assert(not preview.is_running() and alive(pid()) and #opened == count)
    preview.start()
    ready(preview)
    assert(last("doc").path == vim.fs.normalize(vim.api.nvim_buf_get_name(b)))
    emit({ type = "error", fatal = true, message = "試験用の片付け" })
  end)
  test("無効な表示の初期値は system と fluid にする", function()
    config({})
    vim.g.gitlab_preview_appearance = { theme = "invalid", width = "invalid" }
    preview.start()
    ready(preview)
    assert(last("hello").appearance.theme == "system" and last("hello").appearance.width == "fluid")
    emit({ type = "error", fatal = true, message = "試験用の片付け" })
    vim.g.gitlab_preview_appearance = { theme = "dark", width = "fixed" }
  end)
  test("複数行が同時に届いても読めて、不正な行の後も続ける", function()
    config({})
    preview.start()
    ready(preview)
    local before = #warnings
    issue({
      kind = "raw",
      text = "不正なJSON\n"
        .. vim.json.encode({ type = "error", message = "一つ目" })
        .. "\n"
        .. vim.json.encode({ type = "error", message = "二つ目" })
        .. "\n",
    })
    assert(#warnings == before + 3 and warnings[#warnings].message:find("二つ目", 1, true))
    emit({ type = "error", fatal = true, message = "試験用の片付け" })
  end)
  test("ready の版が違うと更新を促し、子を止める", function()
    config({ protocol = 2 })
    preview.start()
    wait("版の違いを知らせる", function()
      return not preview.is_running()
    end)
    assert(warnings[#warnings].message:find("md-preview を更新", 1, true))
    assert(not alive(pid()))
  end)
  test("ready が来なければ時間切れと標準エラーの最後の行を知らせる", function()
    config({ ready = false, stderr = "最初の行\n最後の起動エラー\n" })
    preview.config.ready_timeout_ms = 1500
    preview.start()
    wait("起動が時間切れになる", function()
      return not preview.is_running()
    end)
    assert(
      warnings[#warnings].message:find("時間切れ", 1, true)
        and warnings[#warnings].message:find("最後の起動エラー", 1, true),
      vim.inspect(warnings[#warnings])
    )
    assert(not alive(pid()))
    preview.config.ready_timeout_ms = 1500
  end)
  test("プロセスが勝手に終わったら片付けて、次の start で起こし直せる", function()
    config({})
    preview.start()
    ready(preview)
    local previous = pid()
    issue({ kind = "exit", code = 7 }, true)
    wait("勝手に終わったことを知らせる", function()
      return not preview.is_running()
    end)
    assert(warnings[#warnings].message:find("プレビューのアプリが終了", 1, true))
    commands = {}
    vim.fn.writefile({ "[]" }, vim.fs.joinpath(sandbox, "commands.json"))
    preview.start()
    ready(preview)
    assert(pid() ~= previous)
  end)
  test("install の進行中・成功を知らせ、新しい URL で起こし直す", function()
    config({ installDelay = 100 })
    local previous, url = pid(), preview.url()
    preview.install()
    preview.install()
    assert(warnings[#warnings].message:find("進行中", 1, true))
    wait("導入成功後に子を起こし直す", function()
      return preview.url() and preview.url() ~= url
    end)
    assert(pid() ~= previous and not alive(previous))
    assert(opened[#opened].url == preview.url())
    assert(process_count("install-style") >= 1)
    local found = false
    for _, item in ipairs(warnings) do
      found = found or item.message:find("公式スタイルの導入が完了", 1, true) ~= nil
    end
    assert(found)
  end)
  test("休止中の install も子を更新し、休止を保って新しいURLを開く", function()
    preview.stop()
    config({})
    local previous, count = pid(), #opened
    preview.install()
    wait("休止中も新しいページを開く", function()
      return #opened > count and pid() ~= previous
    end)
    assert(not preview.is_running() and not alive(previous))
    emit({ type = "clients", count = 1 })
    preview.start()
    ready(preview)
  end)
  test("install の失敗は標準エラーの最後の行を示し、プレビューは再起動しない", function()
    config({ installExit = 2, installError = "導入の試験エラー" })
    local previous = pid()
    preview.install()
    wait("導入の失敗を知らせる", function()
      return warnings[#warnings].message:find("導入の試験エラー", 1, true) ~= nil
    end)
    assert(warnings[#warnings].level == vim.log.levels.ERROR and pid() == previous)
  end)
  test("toggle でも pause と resume を送り分ける", function()
    preview.toggle()
    assert(not preview.is_running())
    preview.toggle()
    assert(preview.is_running())
    ready(preview)
  end)
  test("明示的なコマンドとキーの配線を保つ", function()
    local spec = dofile(vim.fs.joinpath(root, "lua", "plugins", "gitlab-preview.lua"))[1]
    spec.config()
    for _, name in ipairs({ "GitLabPreview", "GitLabPreviewStop", "GitLabPreviewToggle", "GitLabPreviewInstall" }) do
      assert(vim.api.nvim_get_commands({})[name])
    end
    assert(spec.keys[1][1] == "<leader>cp")
  end)
  test("設定・PATH・決まった場所に無いときは導入の案内を1回だけ出す", function()
    preview.stop()
    emit({ type = "error", fatal = true, message = "未導入の試験の前に片付ける" })
    local before, count = #warnings, process_count()
    vim.g.gitlab_preview_command = nil
    preview.start()
    preview.start()
    assert(
      #warnings == before + 1 and warnings[#warnings].message:find("md-preview の docs/install.md", 1, true),
      vim.inspect({
        before = before,
        after = #warnings,
        last = warnings[#warnings],
        ft = vim.bo.filetype,
        bt = vim.bo.buftype,
        running = preview.is_running(),
      })
    )
    -- 同じ名前のフォルダーは、決まった場所にあっても実行ファイルとして扱わない。
    vim.fn.mkdir(vim.fs.joinpath(bin, "mdpreview"), "p")
    vim.fn.mkdir(vim.fs.joinpath(bin, "mdpreview.exe"), "p")
    preview.start()
    preview.install()
    assert(#warnings == before + 1 and process_count() == count)
    vim.g.gitlab_preview_command = vim.deepcopy(fake_command)
    config({})
    preview.start()
    ready(preview)
  end)
  test("実行ファイルを起こせないときの知らせを保ち、設定を直すと再開できる", function()
    emit({ type = "error", fatal = true, message = "起動失敗の試験の前に片付ける" })
    local before, count = #warnings, process_count()
    vim.g.gitlab_preview_command = vim.fs.joinpath(sandbox, "存在しないアプリ.exe")
    preview.start()
    assert(not preview.is_running() and #warnings == before + 1)
    assert(warnings[#warnings].message:find("アプリを起動できません", 1, true))
    preview.install()
    assert(
      #warnings == before + 2
        and warnings[#warnings].message:find("導入のアプリを起動できません", 1, true)
    )
    assert(warnings[#warnings].level == vim.log.levels.ERROR and process_count() == count)
    vim.g.gitlab_preview_command = vim.deepcopy(fake_command)
    preview.start()
    ready(preview)
  end)
  test("VimLeavePre 相当で標準入力を閉じ、子が自分で終了する", function()
    config({})
    local previous = pid()
    assert(alive(previous))
    trigger("VimLeavePre")
    wait("子プロセスが終わる", function()
      return not alive(previous)
    end)
    local found = false
    for _, event in ipairs(events("exit")) do
      if event.pid == previous then
        found = event.stdinClosed
      end
    end
    assert(found and not preview.is_running())
  end)
end, debug.traceback)
if preview then
  pcall(vim.api.nvim_exec_autocmds, "VimLeavePre", {})
end
vim.notify, vim.ui.open, vim.system = original.notify, original.open, original.system
vim.fn.exepath, vim.fn.has, uv.os_homedir = original.exepath, original.has, original.homedir
vim.env.MD_PREVIEW_BRIDGE_TEST_DIR = saved_dir
vim.g.gitlab_preview_command, vim.g.gitlab_preview_browser, vim.g.gitlab_preview_appearance = nil, nil, nil
assert(
  vim.fs.normalize(sandbox):sub(1, #root + 8) == root .. "/.tests/",
  "試験の片付けは作業ツリー内だけ"
)
vim.fn.delete(sandbox, "rf")
if not ok then
  io.stderr:write("GitLab プレビューの橋渡しが失敗: " .. tostring(error_message) .. "\n")
  vim.cmd("cquit 1")
end
print(("GitLab プレビューの橋渡し: 成功%d件・失敗0件・skip0件"):format(passed))
