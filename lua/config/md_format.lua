-- Markdown の整形器 md-format (mdfmt) の配線。整形器は別のリポジトリ (ryo-aoki-pc/md-format) にあり、
-- その導入スクリプト (scripts/setup.mjs) が入れた導入先の format.mjs を node で動かす。
-- PATH の mdfmt を使わないのは、Windows で mdfmt.cmd (cmd.exe) を通さず、予備のプロセスが確かめる
-- format.mjs の実体のパスを保つため。導入と更新は setup-notes の手順で行う (Neovim からは導入しない)。
local M = {}
local uv = vim.uv or vim.loop
local configured_dir

---導入先。setup.mjs と同じ決まり (Windows は %LOCALAPPDATA%\md-format、macOS は ~/Library/Application Support/md-format、
---ほかは ${XDG_DATA_HOME:-~/.local/share}/md-format)。lang-markdown.lua の format_dir で変えられる。
---@return string
function M.install_dir()
  if configured_dir and configured_dir ~= "" then
    return vim.fs.normalize(configured_dir)
  end
  local home = uv.os_homedir() or vim.fn.expand("~")
  local base
  if vim.fn.has("win32") == 1 then
    base = vim.env.LOCALAPPDATA or vim.fs.joinpath(home, "AppData", "Local")
  elseif vim.fn.has("mac") == 1 then
    base = vim.fs.joinpath(home, "Library", "Application Support")
  else
    local xdg = vim.env.XDG_DATA_HOME
    base = (xdg and xdg:sub(1, 1) == "/") and xdg or vim.fs.joinpath(home, ".local", "share")
  end
  return vim.fs.joinpath(base, "md-format")
end

---導入先の format.mjs と依存があるか。
---@return boolean
function M.installed()
  local dir = M.install_dir()
  return uv.fs_stat(vim.fs.joinpath(dir, "format.mjs")) ~= nil
    and uv.fs_stat(vim.fs.joinpath(dir, "node_modules")) ~= nil
end

M.missing_message =
  "md-format (mdfmt) が導入されていません。setup-notes の手順で導入してください: "

local function filename(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" or vim.bo[bufnr].buftype ~= "" then
    return vim.fs.joinpath(vim.fn.getcwd(), "__nvim_unnamed__.md")
  end
  return vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
end

-- --config は Node のオプションではなく整形器の引数なので、スクリプト名の後に置く。
---@param opts? {config_path?: string, fixes?: table<string, boolean>}
function M.formatter(opts)
  opts = opts or {}
  local enabled, disabled = {}, {}
  if opts.fixes ~= nil then
    if type(opts.fixes) ~= "table" then
      error("整形対象の fixes は、名前をキー、真偽値を値とする表で指定してください。")
    end
    for name, value in pairs(opts.fixes) do
      if type(name) ~= "string" then
        error("整形対象の fixes のキーは文字列で指定してください。")
      end
      if type(value) ~= "boolean" then
        error("整形対象の fixes[" .. name .. "] は true または false で指定してください。")
      end
      table.insert(value and enabled or disabled, name)
    end
  end
  -- 分類とルール名の検証・既定値は Node 側に任せる。名前は大小文字を区別せずに並べる。
  local function name_order(a, b)
    local lower_a, lower_b = a:lower(), b:lower()
    if lower_a == lower_b then
      return a < b
    end
    return lower_a < lower_b
  end
  table.sort(enabled, name_order)
  table.sort(disabled, name_order)
  local function args(_, ctx)
    local command = {
      vim.fs.joinpath(M.install_dir(), "format.mjs"),
      "--filename",
      filename(ctx.buf),
    }
    if opts.config_path then
      vim.list_extend(command, { "--config", opts.config_path })
    end
    if #enabled > 0 then
      vim.list_extend(command, { "--enable-fixes", table.concat(enabled, ",") })
    end
    if #disabled > 0 then
      vim.list_extend(command, { "--disable-fixes", table.concat(disabled, ",") })
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

-- conform に渡す formatter。バッファごとに設定を返す関数で、予備のプロセス (config.md_format_spare) が使えるときは
-- それに要求を渡す Lua の formatter、使えないときは上の CLI の設定をそのまま返す。md-format が導入されていなければ、
-- バッファを変えずにエラーを返す Lua の formatter を返す (node の Cannot find module の代わりに、導入を促す)。
---@param opts? {config_path?: string, fixes?: table<string, boolean>, spare?: boolean, name?: string, timeout_ms?: integer}
function M.conform_formatter(opts)
  opts = opts or {}
  local job = M.formatter(opts)
  local name = opts.name or "mdfmt"
  local missing = {
    inherit = false,
    format = function(_, _, _, callback)
      callback(string.format("Formatter '%s' error: %s%s", name, M.missing_message, M.install_dir()))
    end,
    range_args = job.range_args,
  }
  if opts.spare == false then
    return function()
      return M.installed() and job or missing
    end
  end
  local spare = require("config.md_format_spare")
  local timeout_ms = opts.timeout_ms or 10000
  local lua_formatter = {
    inherit = false,
    format = function(_, ctx, lines, callback)
      spare.format(job, name, timeout_ms, ctx, lines, callback)
    end,
    -- Lua の formatter でも、conform は range_args の有無で範囲を分け直すかを決める (runner.lua の format_lines_sync)。
    range_args = job.range_args,
  }
  return function()
    if not M.installed() then
      return missing
    end
    return spare.usable() and lua_formatter or job
  end
end

---@param opts? {spare?: boolean, dir?: string}
function M.setup(opts)
  opts = opts or {}
  configured_dir = opts.dir
  require("config.md_format_spare").setup({ enabled = opts.spare ~= false })
end

return M
