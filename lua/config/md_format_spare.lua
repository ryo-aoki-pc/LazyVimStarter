-- Markdown の整形器 (md-format) の予備のプロセス。保存の時間の大半は node の起動と依存の読み込みなので、依存を読み込み終えて
-- 標準入力を待つ node (md-format の導入先の spare.mjs) を 1 つ先に起動しておき、保存のときに要求だけを渡す。
-- 予備は 1 回使ったら終わり、次の予備を起動する。プロジェクトの設定・カスタムルールは要求のときに読むので、
-- 次の保存から必ず効く (同じ node を使い回すと、JS の設定やカスタムルールのモジュールと状態が残る)。
-- 予備が無い・使えないときは、今までどおり conform が CLI (導入先の format.mjs) を起動する。
local M = {}
local uv = vim.uv or vim.loop

local state = {
  enabled = false,
  ---@type table?
  spare = nil,
}
-- 予備が受け付けなかった要求 (見出しの行の誤り・format.mjs の違い・cwd に移れない・標準入力でない依頼) の終了コード。
local TRANSPORT_FAILURE = 86
-- 使い終わった後の次の予備は、保存が終わってから起動する (保存と依存の読み込みが CPU を取り合わないように)。
local RESTART_DELAY_MS = 100

local function read_file(path)
  local fd = uv.fs_open(path, "r", 438)
  if not fd then
    return false
  end
  local stat = uv.fs_fstat(fd)
  local contents = stat and uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)
  return contents or false
end

local function has_markdown_buffer(except)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= except and vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "markdown" then
      return true
    end
  end
  return false
end

-- 予備を起動したときと、保存するときに比べる値。どれかが違えば、今の CLI と同じ結果にならないかもしれないので使わない。
-- 先に読み込む整形器 (導入先の *.mjs) と導入の記録 (install.json)・依存の中身、conform が起動するはずの node (exepath) と
-- リンクの先の実体、環境変数 (PATH・NODE_OPTIONS など)、導入先。依存は lock と主な包みの package.json を比べる
-- (それ以外の node_modules の中の書き換えは見ない)。導入し直すと install.json と lock が変わる。
local function identity()
  local dir = require("config.md_format").install_dir()
  local node = vim.fn.exepath("node")
  local real = node ~= "" and uv.fs_realpath(node) or nil
  local stat = real and uv.fs_stat(real) or nil
  local files = {}
  local scripts = {}
  if uv.fs_stat(dir) then
    for name, kind in vim.fs.dir(dir) do
      if kind == "file" and name:match("%.mjs$") then
        table.insert(scripts, name)
      end
    end
  end
  table.sort(scripts)
  for _, name in ipairs(scripts) do
    files[name] = read_file(vim.fs.joinpath(dir, name))
  end
  for _, name in ipairs({ "install.json", "package.json", "package-lock.json" }) do
    files[name] = read_file(vim.fs.joinpath(dir, name))
  end
  files[".package-lock.json"] = read_file(vim.fs.joinpath(dir, "node_modules", ".package-lock.json"))
  for _, package in ipairs({ "markdownlint-cli2", "markdownlint", "comrak", "js-beautify" }) do
    files[package] = read_file(vim.fs.joinpath(dir, "node_modules", package, "package.json"))
  end
  return {
    node = node,
    node_real = real or false,
    node_stat = stat and { stat.size, stat.mtime.sec, stat.mtime.nsec } or false,
    dir = dir,
    env = vim.fn.environ(),
    files = files,
  }
end

local function kill(spare)
  spare.on_exit = nil
  pcall(spare.proc.kill, spare.proc, "sigterm")
end

---予備を 1 つ起動する (既にある・使わない設定・依存が無いときは何もしない)。
function M.start()
  if not state.enabled or state.spare or not has_markdown_buffer() then
    return
  end
  local md_format = require("config.md_format")
  if not md_format.installed() then
    return
  end
  local spare = { identity = identity() }
  local node = spare.identity.node
  local spare_path = vim.fs.joinpath(md_format.install_dir(), "spare.mjs")
  if node == "" or not uv.fs_stat(spare_path) then
    return
  end
  -- shell を介さず argv で起動する。環境は Neovim のものを継ぐ。依存は spare.mjs の隣 (導入先) から読む。
  -- cwd は要求のときに移るので、待つ間は Neovim のキャッシュのフォルダに置く。導入先にすると、Windows では
  -- プロセスの cwd になっているフォルダを入れ替えられず、md-format の導入し直しが止まる。
  local cache = vim.fn.stdpath("cache")
  vim.fn.mkdir(cache, "p")
  local ok, proc = pcall(vim.system, { node, spare_path }, { stdin = true, text = true, cwd = cache }, function(result)
    spare.exited = true
    vim.schedule(function()
      if state.spare == spare then
        state.spare = nil
      end
      if spare.on_exit then
        spare.on_exit(result)
      end
    end)
  end)
  if ok then
    spare.proc = proc
    state.spare = spare
  end
end

---予備を止める (使っている途中のものは止めない)。
function M.stop()
  local spare = state.spare
  state.spare = nil
  if spare then
    kill(spare)
  end
end

---今の予備が、保存のときの CLI と同じ結果を返せるか。違えば止めて、次の予備を起動し直す。
---予備が無いとき (待つ間に終わったときも) も、次の保存のために起動し直す。
---@return boolean
function M.usable()
  local spare = state.spare
  if not spare or spare.exited then
    vim.defer_fn(M.start, RESTART_DELAY_MS)
    return false
  end
  if vim.deep_equal(identity(), spare.identity) then
    return true
  end
  M.stop()
  vim.defer_fn(M.start, RESTART_DELAY_MS)
  return false
end

---待っている予備のプロセスの pid (無ければ nil)。試験と調べもの用。
---@return integer?
function M.pid()
  local spare = state.spare
  return spare and not spare.exited and spare.proc.pid or nil
end

-- conform の job (runner.lua の vim.system の結果の扱い) と同じ規則で、結果を行かエラーの文言にする。
local function is_empty_output(output)
  return not output or vim.tbl_isempty(output) or (#output == 1 and output[1] == "")
end

local function convert(result, eol, name)
  local stdout = result.stdout and vim.split(result.stdout, "\r?\n") or {}
  local stderr = result.stderr and vim.split(result.stderr, "\r?\n") or {}
  if result.code == 0 then
    local output = stdout
    if eol and output[#output] == "" then
      table.remove(output)
    end
    if #output == 0 then
      table.insert(output, "")
    end
    return nil, output
  end
  local err_str
  if not is_empty_output(stderr) then
    err_str = table.concat(stderr, "\n")
  elseif not is_empty_output(stdout) then
    err_str = table.concat(stdout, "\n")
  else
    err_str = "unknown error"
  end
  return string.format("Formatter '%s' error: %s", name, err_str)
end

---conform の Lua の formatter の本体。予備があれば要求を渡し、無ければ CLI を起動する。
---@param job table md_format.formatter() が返す CLI の設定
---@param name string conform の formatter の名前 (エラーの文言に使う)
---@param timeout_ms integer 保存の整形の上限 (conform は Lua の formatter の子を止めないので、ここで止める)
function M.format(job, name, timeout_ms, ctx, lines, callback)
  local eol = vim.bo[ctx.buf].eol
  -- conform の job と同じバイト列: 行を LF でつなぎ、'eol' なら末尾に LF を足す。
  local text = table.concat(lines, "\n") .. (eol and "\n" or "")
  local argv = (ctx.range and job.range_args or job.args)(job, ctx)
  local finished, active = false, nil
  local timer = assert(uv.new_timer())
  local function close_timer()
    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end
  local function finish(err, output)
    if finished then
      return
    end
    finished = true
    close_timer()
    callback(err, output)
    vim.defer_fn(M.start, RESTART_DELAY_MS)
  end
  local function run_cli()
    -- conform の build_cmd と同じく、command を exepath で実体のパスにしてから起動する。
    local command = vim.fn.exepath(job.command)
    local ok, proc = pcall(
      vim.system,
      vim.list_extend({ command ~= "" and command or job.command }, argv),
      { stdin = text, text = true },
      vim.schedule_wrap(function(result)
        finish(convert(result, eol, name))
      end)
    )
    if ok then
      active = proc
    else
      finish(string.format("Formatter '%s' error in vim.system: %s", name, proc))
    end
  end
  -- 上限で子を止め、遅れた結果は当てない。同期の整形では conform が上限で既に原文のまま返しているので、この知らせは
  -- job が止められた後に返すエラーと同じく後から届くだけ。非同期の整形では、これで conform の整形が終わる。
  timer:start(
    timeout_ms,
    0,
    vim.schedule_wrap(function()
      if finished then
        return
      end
      if active then
        pcall(active.kill, active, "sigterm")
      end
      finish(string.format("Formatter '%s' timeout", name))
    end)
  )
  local spare = state.spare
  state.spare = nil
  if not spare or spare.exited then
    return run_cli()
  end
  active = spare.proc
  spare.on_exit = function(result)
    if finished then
      return
    end
    -- 予備が要求を受け付けなかった (86) か、外からシグナルで止められたときは、整形器の失敗ではないので CLI でやり直す。
    local refused = result.code == TRANSPORT_FAILURE and (result.stdout or "") == "" and (result.stderr or "") == ""
    if refused or (result.signal or 0) ~= 0 then
      return run_cli()
    end
    finish(convert(result, eol, name))
  end
  local header = vim.json.encode({ script = argv[1], argv = vim.list_slice(argv, 2), cwd = uv.cwd() })
  local written = pcall(spare.proc.write, spare.proc, header .. "\n" .. text)
  written = written and pcall(spare.proc.write, spare.proc, nil)
  if not written then
    kill(spare)
    run_cli()
  end
end

---予備を使うかどうかを決め、Markdown のバッファの出入りで予備を起動・停止する。
---@param opts {enabled: boolean}
function M.setup(opts)
  state.enabled = opts.enabled
  local group = vim.api.nvim_create_augroup("md_format_spare", { clear = true })
  if not state.enabled then
    M.stop()
    return
  end
  -- Markdown になったら起動し、ほかの filetype に変えて Markdown のバッファが無くなったら止める。
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function(args)
      if args.match == "markdown" then
        M.start()
      elseif not has_markdown_buffer() then
        M.stop()
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufUnload", {
    group = group,
    callback = function(args)
      if vim.bo[args.buf].filetype == "markdown" and not has_markdown_buffer(args.buf) then
        M.stop()
      end
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      state.enabled = false
      M.stop()
    end,
  })
  M.start()
end

return M
