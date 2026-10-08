-- 実行: nvim --headless -u NONE -i NONE -l tools/glfm-format/test/conform.lua
-- lazy.nvim を起動せず、保存時と同じ同期整形・範囲整形・失敗時の原文保持を確かめる。
local uv = vim.uv or vim.loop
local script = debug.getinfo(1, "S").source:sub(2)
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(script, ":p")))))
local sandbox = vim.fn.tempname()
vim.fn.mkdir(sandbox, "p")
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:append(vim.env.GLFM_CONFORM_DIR or vim.fs.joinpath(vim.fn.stdpath("data"), "lazy", "conform.nvim"))

local glfm = require("config.glfm_format")
local conform = require("conform")
local gate = function()
  return false
end
local opts = {
  formatters_by_ft = { markdown = { "prettier", "markdownlint-cli2", "markdown-toc" } },
  formatters = { ["markdownlint-cli2"] = { condition = gate } },
  default_format_opts = { async = false, timeout_ms = 10000, lsp_format = "fallback" },
}
for _, spec in ipairs(dofile(vim.fs.joinpath(root, "lua", "plugins", "lang-markdown.lua"))) do
  if spec[1] == "stevearc/conform.nvim" and type(spec.opts) == "function" then
    assert(vim.tbl_contains(spec.cmd, "GlfmFormatInstall"))
    spec.opts(nil, opts)
  end
end
assert(vim.deep_equal(opts.formatters_by_ft.markdown, {
  "glfm_markdownlint",
  timeout_ms = 10000,
  lsp_format = "never",
}))
assert(vim.deep_equal(opts.formatters_by_ft["markdown.mdx"], {
  "prettier",
  "markdownlint-cli2",
  timeout_ms = 10000,
}))
assert(opts.formatters["markdownlint-cli2"].condition == gate)
assert(opts.formatters.glfm_markdownlint.condition == nil)
assert(vim.fn.exists(":GlfmFormatInstall") == 2)
conform.setup(opts)
if vim.env.GLFM_FORMAT_RUNTIME_DIR then
  glfm.runtime_dir = function()
    return vim.env.GLFM_FORMAT_RUNTIME_DIR
  end
end

local function buffer(lines)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_name(buf, vim.fs.joinpath(sandbox, "文書 " .. buf .. ".md"))
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return buf
end

local function format(buf, extra)
  local result = {}
  conform.format(
    vim.tbl_extend("force", { bufnr = buf, async = false, quiet = true }, extra or {}),
    function(err, edited)
      result.err = err
      result.edited = edited
    end
  )
  return result, vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

-- 診断が一度も出ていない状態でも、通常の見出しと説明内部の違反が直る。
local first = buffer({ "#Heading", "", "Term", ": Description.   ", "", "    -  One", "    -  Two" })
assert(#vim.diagnostic.get(first) == 0)
local first_result, first_lines = format(first)
assert(not first_result.err, vim.inspect(first_result.err))
assert(first_result.edited)
assert(first_lines[1] == "# Heading")
assert(vim.tbl_contains(first_lines, ": Description."))
assert(vim.tbl_contains(first_lines, "  - One"))
assert(vim.tbl_contains(first_lines, "  - Two"))

-- --config をスクリプト名の後に置き、実ファイル名と空白を含むパスを argv で渡す。
local config_file = vim.fs.joinpath(sandbox, "設定.markdownlint.jsonc")
local args = glfm.formatter({ config_path = config_file }).args(nil, { buf = first })
assert(args[1] == vim.fs.joinpath(root, "tools", "glfm-format", "format.mjs"))
assert(args[4] == "--filename")
assert(args[5] == vim.api.nvim_buf_get_name(first))
assert(args[6] == "--config" and args[7] == config_file)
local range_args = glfm.formatter().range_args(nil, { buf = first, range = { start = { 4, 2 }, ["end"] = { 5, 7 } } })
assert(vim.deep_equal(vim.list_slice(range_args, 6), {
  "--range-start",
  "4",
  "--range-end",
  "5",
  "--range-start-column",
  "2",
  "--range-end-column",
  "7",
}))

local selected = buffer({ "#Outside", "", "#Selected", "", "Term", ": Description.   " })
local selected_result, selected_lines = format(selected, { range = { start = { 3, 0 }, ["end"] = { 3, 9 } } })
assert(not selected_result.err, vim.inspect(selected_result.err))
assert(selected_lines[1] == "#Outside")
assert(selected_lines[3] == "# Selected")
assert(selected_lines[#selected_lines] == ": Description.   ")

-- 一項目だけの記号変更でリストが分かれる場合は見送り、選択内の末尾空白は直す。
vim.fn.writefile(
  { vim.json.encode({ default = false, MD004 = { style = "dash" }, MD009 = true }) },
  vim.fs.joinpath(sandbox, ".markdownlint.json")
)
local task_input = { "Term", ": Description ", "", "  * [~] First task ", "  * [x] Second task " }
local task_buf = buffer(task_input)
local task_result, task_lines = format(task_buf, { range = { start = { 4, 0 }, ["end"] = { 4, #task_input[4] - 1 } } })
assert(not task_result.err, vim.inspect(task_result.err))
assert(vim.deep_equal(task_lines, { "Term", ": Description ", "", "  * [~] First task", "  * [x] Second task " }))
local partial_task_buf = buffer(task_input)
local partial_result, partial_lines = format(partial_task_buf, { range = { start = { 4, 0 }, ["end"] = { 5, 0 } } })
assert(not partial_result.err, vim.inspect(partial_result.err))
assert(vim.deep_equal(partial_lines, task_lines))
vim.fn.delete(vim.fs.joinpath(sandbox, ".markdownlint.json"))

-- 以前の markdownlint-cli2 --fix と同じく、Neovim の作業ディレクトリにあるプロジェクト設定が
-- 下のフォルダーのバッファにも効く。末尾の余分な空行も消える。
vim.fn.writefile(
  { vim.json.encode({ default = false, MD004 = { style = "asterisk" }, MD012 = true }) },
  vim.fs.joinpath(sandbox, ".markdownlint.json")
)
vim.fn.mkdir(vim.fs.joinpath(sandbox, "下の階層"), "p")
local previous_cwd = vim.fn.getcwd()
vim.api.nvim_set_current_dir(sandbox)
local nested = buffer({ "- one", "- two", "" })
vim.api.nvim_buf_set_name(nested, vim.fs.joinpath(sandbox, "下の階層", "文書.md"))
local nested_result, nested_lines = format(nested)
assert(not nested_result.err, vim.inspect(nested_result.err))
assert(vim.deep_equal(nested_lines, { "* one", "* two" }), vim.inspect(nested_lines))
vim.api.nvim_set_current_dir(previous_cwd)
vim.fn.delete(vim.fs.joinpath(sandbox, ".markdownlint.json"))

-- runtime 未導入時はエラーにし、stock markdownlint や LSP の結果へ置き換えない。
local runtime_dir = glfm.runtime_dir
glfm.runtime_dir = function()
  return vim.fs.joinpath(sandbox, "missing-runtime")
end
local missing_input = { "#Heading", "", "Term", ": Description.   " }
local missing = buffer(missing_input)
local missing_result, missing_lines = format(missing)
assert(missing_result.err)
assert(vim.deep_equal(missing_lines, missing_input))
glfm.runtime_dir = runtime_dir

-- 外部プロセスを使うので、conform の timeout が待機だけでなくプロセスにも効く。
conform.formatters.glfm_timeout_test = {
  inherit = false,
  command = "node",
  args = { "-e", "setTimeout(() => {}, 5000)" },
  stdin = true,
}
local timeout_buf = buffer({ "変更しない" })
local began = uv.hrtime()
local timeout_result, timeout_lines = format(timeout_buf, {
  formatters = { "glfm_timeout_test" },
  timeout_ms = 30,
  lsp_format = "never",
})
assert(timeout_result.err and timeout_result.err:lower():find("timeout", 1, true))
assert((uv.hrtime() - began) / 1e6 < 1000)
assert(vim.deep_equal(timeout_lines, { "変更しない" }))

-- 導入テストはプロセスだけを置き換え、通信せず manifest のコピーと argv を確かめる。
local original_system, original_exepath = vim.system, vim.fn.exepath
local source_dir = vim.fs.joinpath(sandbox, "source")
local install_dir = vim.fs.joinpath(sandbox, "runtime")
vim.fn.mkdir(source_dir, "p")
vim.fn.writefile({ '{"private":true}' }, vim.fs.joinpath(source_dir, "package.json"))
vim.fn.writefile({ '{"lockfileVersion":3}' }, vim.fs.joinpath(source_dir, "package-lock.json"))
local calls = {}
local npm_result = { code = 0, stdout = "", stderr = "" }
vim.system = function(command, options, callback)
  calls[#calls + 1] = { command = vim.deepcopy(command), options = options }
  if command[2] == "-p" then
    callback({ code = 0, stdout = vim.json.encode({ version = "v22.0.0", execPath = original_exepath("node") }) })
  else
    callback(npm_result)
  end
  return {}
end

local function install()
  local outcome
  assert(glfm.install({ source_dir = source_dir, runtime_dir = install_dir, quiet = true }, function(ok, message)
    outcome = { ok = ok, message = message }
  end))
  assert(vim.wait(1000, function()
    return outcome ~= nil
  end, 5))
  return outcome
end

assert(install().ok)
assert(vim.tbl_contains(calls[2].command, "ci"))
assert(vim.tbl_contains(calls[2].command, "--ignore-scripts"))
assert(vim.tbl_contains(calls[2].command, install_dir))
local copied_lock = vim.fs.joinpath(install_dir, "package-lock.json")
assert(uv.fs_utime(copied_lock, 100, 100))
assert(install().ok)
assert(uv.fs_stat(copied_lock).mtime.sec == 100, "同じ manifest を再コピーしない")
npm_result = { code = 1, stdout = "", stderr = "offline" }
local failed = install()
assert(not failed.ok and failed.message:find("offline", 1, true))

-- Scoop の npm.cmd shim の隣に npm-cli.js がない場合は、Node の実体の隣を探す。
local app_dir = vim.fs.joinpath(sandbox, "node-app")
local npm_cli = vim.fs.joinpath(app_dir, "node_modules", "npm", "bin", "npm-cli.js")
vim.fn.mkdir(vim.fs.dirname(npm_cli), "p")
vim.fn.writefile({}, npm_cli)
vim.fn.exepath = function(name)
  return name == "node" and vim.fs.joinpath(app_dir, "node.exe") or vim.fs.joinpath(sandbox, "shims", "npm.cmd")
end
vim.system = function(command, options, callback)
  calls[#calls + 1] = { command = vim.deepcopy(command), options = options }
  callback(command[2] == "-p" and {
    code = 0,
    stdout = vim.json.encode({ version = "v22.0.0", execPath = vim.fs.joinpath(app_dir, "node.exe") }),
  } or { code = 0, stdout = "", stderr = "" })
  return {}
end
assert(install().ok)
assert(calls[#calls].command[1] == vim.fs.joinpath(app_dir, "node.exe"))
assert(calls[#calls].command[2] == npm_cli)
vim.system, vim.fn.exepath = original_system, original_exepath
vim.fn.delete(sandbox, "rf")
print("GLFM conform / installer integration: PASS")
