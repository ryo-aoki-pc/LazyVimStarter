-- GLFM 整形器の配線と、明示的に実行したときだけ動く依存の導入。
local M = {}
local uv = vim.uv or vim.loop
local module_path = debug.getinfo(1, "S").source:sub(2)
local config_dir = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(module_path)))
local installing = false

function M.source_dir()
  return vim.fs.joinpath(config_dir, "tools", "glfm-format")
end

function M.runtime_dir()
  return vim.fs.joinpath(vim.fn.stdpath("data"), "glfm-format")
end

local function filename(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" or vim.bo[bufnr].buftype ~= "" then
    return vim.fs.joinpath(vim.fn.getcwd(), "__nvim_unnamed__.md")
  end
  return vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
end

-- --config は Node のオプションではなく整形器の引数なので、スクリプト名の後に置く。
function M.formatter(opts)
  opts = opts or {}
  local function args(_, ctx)
    local command = {
      vim.fs.joinpath(M.source_dir(), "format.mjs"),
      "--runtime-dir",
      M.runtime_dir(),
      "--filename",
      filename(ctx.buf),
    }
    if opts.config_path then
      vim.list_extend(command, { "--config", opts.config_path })
    end
    if ctx.range then
      vim.list_extend(command, {
        "--range-start",
        tostring(ctx.range.start[1]),
        "--range-end",
        tostring(ctx.range["end"][1]),
      })
      for _, endpoint in ipairs({ "start", "end" }) do
        local column = ctx.range[endpoint][2]
        if column ~= nil then
          vim.list_extend(command, { "--range-" .. endpoint .. "-column", tostring(column) })
        end
      end
    end
    return command
  end
  return {
    inherit = false,
    command = "node",
    stdin = true,
    args = args,
    -- 範囲の絞り込みは構造検証の前に整形器側で行う。conform が差分を再分割すると、
    -- リスト全体では安全な記号変更を一項目だけに適用して構造を変えることがある。
    range_args = args,
  }
end

local function read_file(path)
  local fd = assert(uv.fs_open(path, "r", 438))
  local stat = assert(uv.fs_fstat(fd))
  local contents, err = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)
  return assert(contents, err)
end

local function copy_manifests(source_dir, runtime_dir)
  vim.fn.mkdir(runtime_dir, "p")
  for _, name in ipairs({ "package.json", "package-lock.json" }) do
    local source = vim.fs.joinpath(source_dir, name)
    local destination = vim.fs.joinpath(runtime_dir, name)
    local contents = read_file(source)
    local ok, existing = pcall(read_file, destination)
    if not ok or contents ~= existing then
      assert(uv.fs_copyfile(source, destination))
    end
  end
end

-- Windows の npm.cmd を shell に渡さず、同梱の npm-cli.js を Node で直接起動する。
-- Unix の npm も symlink の実体が JavaScript なら同じ経路を使う。
local function npm_command(node, npm, exec_path)
  local resolved = uv.fs_realpath(npm) or npm
  if resolved:match("%.js$") then
    return { node, resolved }
  end
  if vim.fn.has("win32") == 1 or npm:lower():match("%.cmd$") or npm:lower():match("%.bat$") then
    -- Scoop の PATH には app 本体ではなく shim の npm.cmd が載ることもある。
    -- Node 自身が返した実行ファイルの隣も探すので、shim を shell で実行する必要がない。
    local candidates = {
      vim.fs.joinpath(vim.fs.dirname(resolved), "node_modules", "npm", "bin", "npm-cli.js"),
      vim.fs.joinpath(vim.fs.dirname(exec_path), "node_modules", "npm", "bin", "npm-cli.js"),
    }
    for _, cli in ipairs(candidates) do
      if uv.fs_stat(cli) then
        return { node, cli }
      end
    end
    error("npm-cli.js が見つかりません。Node.js 22 以上と npm を入れ直してください。")
  end
  return { npm }
end

---@param opts? {source_dir?: string, runtime_dir?: string, quiet?: boolean}
---@param callback? fun(ok: boolean, message: string)
---@return boolean started
function M.install(opts, callback)
  opts = opts or {}
  local function report(ok, message)
    if not opts.quiet then
      vim.notify(message, ok and vim.log.levels.INFO or vim.log.levels.ERROR, { title = "GLFM 整形" })
    end
    if callback then
      callback(ok, message)
    end
  end
  if installing then
    report(false, "GLFM 整形器の導入は実行中です。完了を待ってください。")
    return false
  end
  local node = vim.fn.exepath("node")
  local npm = vim.fn.exepath("npm")
  if node == "" or npm == "" then
    report(
      false,
      "Node.js 22 以上と npm が必要です。導入後に :GlfmFormatInstall を実行してください。"
    )
    return false
  end
  local source_dir = opts.source_dir or M.source_dir()
  local runtime_dir = opts.runtime_dir or M.runtime_dir()
  installing = true
  local function finish(success, message)
    installing = false
    report(success, message)
  end
  if not opts.quiet then
    vim.notify("GLFM 整形器の依存を導入しています。", vim.log.levels.INFO, { title = "GLFM 整形" })
  end
  -- 普段の保存からは呼ばない。版の確認も npm ci も argv で起動し、shell を介さない。
  local started, err = pcall(
    vim.system,
    { node, "-p", "JSON.stringify({version:process.version,execPath:process.execPath})" },
    { text = true, timeout = 10000 },
    vim.schedule_wrap(function(version)
      local parsed, info = pcall(vim.json.decode, version.stdout or "")
      local major = parsed and type(info) == "table" and tonumber((info.version or ""):match("^v(%d+)"))
      if version.code ~= 0 or not major or major < 22 or type(info.execPath) ~= "string" then
        finish(
          false,
          "Node.js 22 以上が必要です。更新後に :GlfmFormatInstall を実行してください。"
        )
        return
      end
      local resolved, command = pcall(npm_command, node, npm, info.execPath)
      if not resolved then
        finish(false, tostring(command))
        return
      end
      local copied, copy_err = pcall(copy_manifests, source_dir, runtime_dir)
      if not copied then
        finish(false, "GLFM 整形器の依存定義をコピーできません: " .. tostring(copy_err))
        return
      end
      vim.list_extend(command, { "ci", "--prefix", runtime_dir, "--ignore-scripts", "--no-audit", "--no-fund" })
      local spawned, spawn_err = pcall(
        vim.system,
        command,
        { text = true, timeout = 300000 },
        vim.schedule_wrap(function(result)
          if result.code == 0 then
            finish(true, "GLFM 整形器の導入が完了しました。")
          else
            local details = vim.trim((result.stderr or "") .. "\n" .. (result.stdout or ""))
            if details == "" then
              details = "npm ci の終了コード: " .. result.code
            end
            finish(false, "GLFM 整形器の導入に失敗しました: " .. details:sub(-4000))
          end
        end)
      )
      if not spawned then
        finish(false, "npm ci を起動できません: " .. tostring(spawn_err))
      end
    end)
  )
  if not started then
    finish(false, "Node.js を起動できません: " .. tostring(err))
    return false
  end
  return true
end

function M.setup()
  vim.api.nvim_create_user_command("GlfmFormatInstall", function()
    M.install()
  end, { desc = "GLFM 整形器の依存を導入", force = true })
end

return M
