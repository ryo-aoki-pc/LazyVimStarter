-- 実行: nvim --headless -u NONE -i NONE -l tests/md_format_conform.lua
-- lazy.nvim を起動せず、保存時と同じ同期整形・範囲整形・失敗時の原文保持を確かめる。
-- 整形器は導入した md-format (既定の導入先か、環境変数 MD_FORMAT_DIR のフォルダ) を使う。
local uv = vim.uv or vim.loop
local script = debug.getinfo(1, "S").source:sub(2)
local root = vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(script, ":p")))
local sandbox = vim.fn.tempname()
vim.fn.mkdir(sandbox, "p")
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:append(
  vim.env.MD_FORMAT_CONFORM_DIR or vim.fs.joinpath(vim.fn.stdpath("data"), "lazy", "conform.nvim")
)

local md_format = require("config.md_format")
local conform = require("conform")
local gate = function()
  return false
end
local opts = {
  formatters_by_ft = { markdown = { "prettier", "markdownlint-cli2", "markdown-toc" } },
  formatters = { ["markdownlint-cli2"] = { condition = gate } },
  default_format_opts = { async = false, timeout_ms = 10000, lsp_format = "fallback" },
}
-- spec が既定の空の format_fixes を整形器に渡すことも確かめる。
local original_formatter = md_format.formatter
local formatter_options
md_format.formatter = function(options)
  formatter_options = options
  return original_formatter(options)
end
for _, spec in ipairs(dofile(vim.fs.joinpath(root, "lua", "plugins", "lang-markdown.lua"))) do
  if spec[1] == "stevearc/conform.nvim" and type(spec.opts) == "function" then
    -- Neovim からは導入しないので、導入のコマンドで conform を読み込まない。
    assert(spec.cmd == nil)
    -- 予備のプロセスを Markdown を開いた時点で起動するため、conform も Markdown で読み込む。
    assert(vim.tbl_contains(spec.ft, "markdown"))
    spec.opts(nil, opts)
  end
end
md_format.formatter = original_formatter
assert(formatter_options and vim.deep_equal(formatter_options.fixes, {}))
assert(formatter_options.spare == true and formatter_options.timeout_ms == 10000)
assert(vim.deep_equal(opts.formatters_by_ft.markdown, {
  "mdfmt",
  timeout_ms = 10000,
  lsp_format = "never",
}))
assert(vim.deep_equal(opts.formatters_by_ft["markdown.mdx"], {
  "prettier",
  "markdownlint-cli2",
  timeout_ms = 10000,
}))
assert(opts.formatters["markdownlint-cli2"].condition == gate)
-- バッファごとに、予備のプロセスに渡す Lua の formatter か、CLI の設定を返す関数。
assert(type(opts.formatters.mdfmt) == "function")
assert(vim.fn.exists(":GlfmFormatInstall") == 0, "Neovim から導入するコマンドは無い")
conform.setup(opts)
local original_install_dir = md_format.install_dir
if vim.env.MD_FORMAT_DIR then
  md_format.install_dir = function()
    return vim.env.MD_FORMAT_DIR
  end
end
assert(md_format.installed(), "md-format を導入してから動かす: " .. md_format.install_dir())
local install_dir = md_format.install_dir()
local spare = require("config.md_format_spare")

local function alive(pid)
  return pid ~= nil and uv.kill(pid, 0) == 0
end

local function buffer(lines)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_name(buf, vim.fs.joinpath(sandbox, "文書 " .. buf .. ".md"))
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return buf
end

-- 保存と同じ経路で整形する。予備のプロセスを先に用意し (as_is のときは今の状態のまま)、使えたかを 3 つ目の値で返す
-- (この節の試験は、保存のときと同じく予備を通る)。
local function format(buf, extra, as_is)
  local result = {}
  if not as_is then
    spare.start()
  end
  local via_spare = spare.usable()
  conform.format(
    vim.tbl_extend("force", { bufnr = buf, async = false, quiet = true }, extra or {}),
    function(err, edited)
      result.err = err
      result.edited = edited
    end
  )
  return result, vim.api.nvim_buf_get_lines(buf, 0, -1, false), via_spare
end

-- 診断が一度も出ていない状態でも、通常の見出しと説明内部の違反が直る。
local first = buffer({ "#  Heading", "", "Term", ": Description.   ", "", "    -  One", "    -  Two" })
assert(#vim.diagnostic.get(first) == 0)
local first_result, first_lines, first_via_spare = format(first)
assert(first_via_spare, "予備のプロセスを通って整形する")
assert(not first_result.err, vim.inspect(first_result.err))
assert(first_result.edited)
assert(first_lines[1] == "# Heading")
assert(vim.tbl_contains(first_lines, ": Description."))
assert(vim.tbl_contains(first_lines, "  - One"))
assert(vim.tbl_contains(first_lines, "  - Two"))

-- 保存と同じ経路でも、課題の参照 (#123) は見出しにせず、同じ行の末尾の空白だけを直す。
local reference = buffer({ "#123 の対応 ", "", "本文" })
local reference_result, reference_lines = format(reference)
assert(not reference_result.err, vim.inspect(reference_result.err))
assert(vim.deep_equal(reference_lines, { "#123 の対応", "", "本文" }), vim.inspect(reference_lines))

-- 埋め込んだ HTML の表と折りたたみも、保存と同じ経路 (予備) と、予備を使わない CLI で同じに整形する。
local html_lines =
  { "<table><tr><td>a</td></tr></table>", "", "<details>", "<summary>概要</summary>", "", "本文", "", "</details>" }
local html_expected = {
  "<table>",
  "  <tr>",
  "    <td>a</td>",
  "  </tr>",
  "</table>",
  "",
  "<details>",
  "  <summary>概要</summary>",
  "",
  "本文",
  "",
  "</details>",
}
local html_result, html_formatted, html_via_spare = format(buffer(html_lines))
assert(html_via_spare, "HTML の整形も予備のプロセスを通る")
assert(not html_result.err, vim.inspect(html_result.err))
assert(vim.deep_equal(html_formatted, html_expected), vim.inspect(html_formatted))
-- Markdown のバッファを作ると予備が起動するので、作ってから止める。
local html_cli = buffer(html_lines)
spare.stop()
local html_cli_result, html_cli_formatted, html_cli_via_spare = format(html_cli, nil, true)
assert(not html_cli_via_spare, "予備を止めると CLI で整形する")
assert(not html_cli_result.err, vim.inspect(html_cli_result.err))
assert(vim.deep_equal(html_cli_formatted, html_expected), vim.inspect(html_cli_formatted))

-- --config をスクリプト名の後に置き、実ファイル名と空白を含むパスを argv で渡す。
local config_file = vim.fs.joinpath(sandbox, "設定.markdownlint.jsonc")
-- 導入先の format.mjs を直接動かし、依存の場所 (--runtime-dir) は渡さない (format.mjs の隣の node_modules を使う)。
local args = md_format.formatter({ config_path = config_file }).args(nil, { buf = first })
assert(args[1] == vim.fs.joinpath(install_dir, "format.mjs"))
assert(args[2] == "--filename")
assert(args[3] == vim.api.nvim_buf_get_name(first))
assert(args[4] == "--config" and args[5] == config_file)
assert(not vim.tbl_contains(args, "--runtime-dir"))
local range_args =
  md_format.formatter().range_args(nil, { buf = first, range = { start = { 4, 2 }, ["end"] = { 5, 7 } } })
assert(vim.deep_equal(vim.list_slice(range_args, 4), {
  "--range-start",
  "4",
  "--range-end",
  "5",
  "--range-start-column",
  "2",
  "--range-end-column",
  "7",
}))

-- 整形対象の true / false を名前順に分け、通常整形と範囲整形で同じ順序にする。
local fixes_formatter = md_format.formatter({
  config_path = config_file,
  fixes = { lists = false, MD026 = true, heading_conversion = true },
})
local fixes_args = fixes_formatter.args(nil, { buf = first })
assert(vim.deep_equal(vim.list_slice(fixes_args, 1, 5), args))
assert(vim.deep_equal(vim.list_slice(fixes_args, 6), {
  "--enable-fixes",
  "heading_conversion,MD026",
  "--disable-fixes",
  "lists",
}))
local fixes_range_args = fixes_formatter.range_args(nil, {
  buf = first,
  range = { start = { 4, 2 }, ["end"] = { 5, 7 } },
})
assert(vim.deep_equal(vim.list_slice(fixes_range_args, 1, #fixes_args), fixes_args))
assert(vim.deep_equal(vim.list_slice(fixes_range_args, #fixes_args + 1), vim.list_slice(range_args, 4)))

-- 片方だけの指定では、空になる側のオプションを渡さない。
local enabled_only = md_format.formatter({ fixes = { MD026 = true, heading_conversion = true } })
assert(vim.deep_equal(vim.list_slice(enabled_only.args(nil, { buf = first }), 4), {
  "--enable-fixes",
  "heading_conversion,MD026",
}))
local disabled_only = md_format.formatter({ fixes = { whitespace = false, lists = false } })
assert(vim.deep_equal(vim.list_slice(disabled_only.args(nil, { buf = first }), 4), {
  "--disable-fixes",
  "lists,whitespace",
}))

-- nil と空の表では引数を増やさず、spec が作った整形器も同じ引数になる。
local default_args = md_format.formatter().args(nil, { buf = first })
assert(vim.deep_equal(md_format.formatter({ fixes = nil }).args(nil, { buf = first }), default_args))
assert(vim.deep_equal(md_format.formatter({ fixes = {} }).args(nil, { buf = first }), default_args))
local default_range = { buf = first, range = { start = { 4, 2 }, ["end"] = { 5, 7 } } }
assert(vim.deep_equal(md_format.formatter({ fixes = nil }).range_args(nil, default_range), range_args))
assert(vim.deep_equal(md_format.formatter({ fixes = {} }).range_args(nil, default_range), range_args))
-- spec の整形器は、予備が無ければ CLI の設定そのものを、あれば同じ範囲の引数を持つ Lua の formatter を返す。
spare.stop()
local spec_job = opts.formatters.mdfmt(first)
assert(spec_job.command == "node" and spec_job.format == nil)
assert(vim.deep_equal(spec_job.args(nil, { buf = first }), default_args))
assert(vim.deep_equal(spec_job.range_args(nil, default_range), range_args))
spare.start()
local spec_lua = opts.formatters.mdfmt(first)
assert(type(spec_lua.format) == "function" and spec_lua.command == nil)
assert(vim.deep_equal(spec_lua.range_args(nil, default_range), range_args))
assert(md_format.conform_formatter({ spare = false })().command == "node", "spare = false なら CLI の設定だけ")

-- 値とキーの型が不正なら、日本語のエラーで設定の誤りを知らせる。
for _, value in ipairs({ "false", 0, {} }) do
  local ok, err = pcall(md_format.formatter, { fixes = { lists = value } })
  assert(not ok and tostring(err):find("fixes[lists] は true または false", 1, true))
end
local invalid_key_ok, invalid_key_err = pcall(md_format.formatter, { fixes = { [1] = true } })
assert(not invalid_key_ok and tostring(invalid_key_err):find("キーは文字列", 1, true))
local invalid_table_ok, invalid_table_err = pcall(md_format.formatter, { fixes = false })
assert(not invalid_table_ok and tostring(invalid_table_err):find("表で指定", 1, true))

local selected = buffer({ "#  Outside", "", "#  Selected", "", "Term", ": Description.   " })
local selected_result, selected_lines = format(selected, { range = { start = { 3, 0 }, ["end"] = { 3, 11 } } })
assert(not selected_result.err, vim.inspect(selected_result.err))
assert(selected_lines[1] == "#  Outside")
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

-- md-format が導入されていなければ、導入を促すエラーにし、stock markdownlint や LSP の結果へ置き換えない。
local install_dir_function = md_format.install_dir
md_format.install_dir = function()
  return vim.fs.joinpath(sandbox, "missing-install")
end
local missing_input = { "#  Heading", "", "Term", ": Description.   " }
local missing = buffer(missing_input)
local missing_result, missing_lines = format(missing, nil, true)
assert(missing_result.err and missing_result.err:find(md_format.missing_message, 1, true), vim.inspect(missing_result))
assert(not missing_result.edited)
assert(vim.deep_equal(missing_lines, missing_input))
md_format.install_dir = install_dir_function
local recovered_result, recovered_lines = format(missing)
assert(not recovered_result.err, vim.inspect(recovered_result.err))
assert(recovered_result.edited)
assert(vim.deep_equal(recovered_lines, { "# Heading", "", "Term", ": Description." }))
local recovered_again, recovered_again_lines = format(missing)
assert(not recovered_again.err, vim.inspect(recovered_again.err))
assert(not recovered_again.edited)
assert(vim.deep_equal(recovered_again_lines, recovered_lines))

-- 壊れた設定を直すと、失敗時に保持した同じバッファを再整形できる。
vim.fn.writefile({ "{ broken JSON" }, config_file)
conform.formatters.mdfmt_config_test = md_format.formatter({ config_path = config_file })
local config_input = { "#  Heading", "", "Term", ": Description.   " }
local config_buf = buffer(config_input)
local config_result, config_lines = format(config_buf, { formatters = { "mdfmt_config_test" }, lsp_format = "never" })
assert(config_result.err)
assert(not config_result.edited)
assert(vim.deep_equal(config_lines, config_input))
vim.fn.writefile({ vim.json.encode({ default = false, MD019 = true, MD009 = true }) }, config_file)
local fixed_config_result, fixed_config_lines =
  format(config_buf, { formatters = { "mdfmt_config_test" }, lsp_format = "never" })
assert(not fixed_config_result.err, vim.inspect(fixed_config_result.err))
assert(fixed_config_result.edited)
assert(vim.deep_equal(fixed_config_lines, { "# Heading", "", "Term", ": Description." }))

-- 不正な範囲指定を CLI が拒否しても原文を保持し、正しい範囲で再試行できる。
local invalid_range_buf = buffer({ "#  Heading" })
local invalid_range_result, invalid_range_lines =
  format(invalid_range_buf, { range = { start = { 0, 0 }, ["end"] = { 1, 0 } } })
assert(invalid_range_result.err)
assert(not invalid_range_result.edited)
assert(vim.deep_equal(invalid_range_lines, { "#  Heading" }))
local valid_range_result, valid_range_lines =
  format(invalid_range_buf, { range = { start = { 1, 0 }, ["end"] = { 1, 9 } } })
assert(not valid_range_result.err, vim.inspect(valid_range_result.err))
assert(valid_range_result.edited)
assert(vim.deep_equal(valid_range_lines, { "# Heading" }))

-- 外部プロセスを使うので、conform の timeout が待機だけでなくプロセスにも効く。
conform.formatters.mdfmt_timeout_test = {
  inherit = false,
  command = "node",
  args = { "-e", "setTimeout(() => {}, 5000)" },
  stdin = true,
}
local timeout_buf = buffer({ "#  Heading" })
local began = uv.hrtime()
local timeout_result, timeout_lines = format(timeout_buf, {
  formatters = { "mdfmt_timeout_test" },
  timeout_ms = 30,
  lsp_format = "never",
})
assert(timeout_result.err and timeout_result.err:lower():find("timeout", 1, true))
assert(not timeout_result.edited)
assert((uv.hrtime() - began) / 1e6 < 1000)
assert(vim.deep_equal(timeout_lines, { "#  Heading" }))
local timeout_retry_result, timeout_retry_lines = format(timeout_buf)
assert(not timeout_retry_result.err, vim.inspect(timeout_retry_result.err))
assert(timeout_retry_result.edited)
assert(vim.deep_equal(timeout_retry_lines, { "# Heading" }))

-- 予備のプロセスを通した結果 (行・edited・エラーの文言) が、CLI の job と同じになる。
conform.formatters.mdfmt_cli_test = md_format.formatter({ config_path = config_file })
conform.formatters.mdfmt_spare_test =
  md_format.conform_formatter({ config_path = config_file, name = "mdfmt_spare_test" })
local function compare(lines, extra, setup_buf)
  local outcomes = {}
  for _, name in ipairs({ "mdfmt_cli_test", "mdfmt_spare_test" }) do
    local buf = buffer(lines)
    if setup_buf then
      setup_buf(buf)
    end
    local result, formatted, via_spare =
      format(buf, vim.tbl_extend("force", { formatters = { name }, lsp_format = "never" }, extra or {}))
    if name == "mdfmt_spare_test" then
      assert(via_spare, "予備のプロセスを通る")
    end
    outcomes[#outcomes + 1] = {
      err = result.err and result.err:gsub(name, "<name>"),
      edited = result.edited,
      lines = formatted,
      eol = vim.bo[buf].eol,
    }
  end
  assert(vim.deep_equal(outcomes[1], outcomes[2]), vim.inspect(outcomes))
  return outcomes[1]
end
vim.fn.writefile({ vim.json.encode({ default = true }) }, config_file)
local normal_input =
  { "#  Heading", "", "Term", ": Description.   ", "", "    -  One", "    -  Two", "", "#123 の対応 " }
assert(compare(normal_input).edited)
assert(not compare({ "" }).edited)
local no_eol = compare({ "#  末尾の改行なし  " }, nil, function(buf)
  vim.bo[buf].eol = false
end)
assert(no_eol.edited and not no_eol.eol)
compare({ "#  Outside", "", "#  Selected  " }, { range = { start = { 3, 0 }, ["end"] = { 3, 13 } } })
vim.fn.writefile({ "{ broken JSON" }, config_file)
local broken = compare({ "#  Heading" })
assert(
  broken.err and broken.err:find("Formatter '<name>' error: mdfmt: Markdown の整形に失敗しました", 1, true),
  broken.err
)
vim.fn.writefile({ vim.json.encode({ default = true }) }, config_file)

-- 予備を起動した後に書いたプロジェクトの設定も、次の保存で効く (予備は要求のときに設定を読む)。
local project = vim.fs.joinpath(sandbox, "後から設定")
vim.fn.mkdir(project, "p")
local late_buf = buffer({ "- one", "- two" })
vim.api.nvim_buf_set_name(late_buf, vim.fs.joinpath(project, "文書.md"))
spare.start()
assert(spare.usable())
vim.fn.writefile(
  { vim.json.encode({ default = false, MD004 = { style = "asterisk" } }) },
  vim.fs.joinpath(project, ".markdownlint.json")
)
local late_result, late_lines, late_via_spare = format(late_buf, { formatters = { "mdfmt_spare_test" } })
assert(late_via_spare and not late_result.err, vim.inspect(late_result.err))
assert(vim.deep_equal(late_lines, { "* one", "* two" }), vim.inspect(late_lines))

-- 上限を過ぎたら予備のプロセスを止め、遅れて届く結果も当てない。
local slow = vim.fs.joinpath(sandbox, "遅いルール")
vim.fn.mkdir(slow, "p")
vim.fn.writefile({
  "module.exports = { names: ['slow-rule'], description: 'slow', tags: ['test'], parser: 'none',",
  "  function: () => { const end = Date.now() + 2000; while (Date.now() < end) {} } };",
}, vim.fs.joinpath(slow, "slow-rule.cjs"))
vim.fn.writefile(
  { vim.json.encode({ customRules = { "./slow-rule.cjs" }, config = { default = true } }) },
  vim.fs.joinpath(slow, ".markdownlint-cli2.jsonc")
)
-- --config を渡すと、markdownlint-cli2 はカスタムルールをその設定の場所から探すので、ここでは渡さない。
conform.formatters.mdfmt_spare_slow = md_format.conform_formatter({ name = "mdfmt_spare_slow", timeout_ms = 300 })
local slow_buf = buffer({ "#  遅い" })
vim.api.nvim_buf_set_name(slow_buf, vim.fs.joinpath(slow, "文書.md"))
spare.start()
local slow_pid = spare.pid()
local slow_began = uv.hrtime()
local slow_result, slow_lines, slow_via_spare =
  format(slow_buf, { formatters = { "mdfmt_spare_slow" }, timeout_ms = 300, lsp_format = "never" })
assert(
  slow_via_spare and slow_result.err and slow_result.err:lower():find("timeout", 1, true),
  vim.inspect(slow_result)
)
assert((uv.hrtime() - slow_began) / 1e6 < 1500)
assert(
  vim.wait(1500, function()
    return not alive(slow_pid)
  end, 20),
  "上限を過ぎた予備のプロセスが止まる"
)
vim.wait(2500)
assert(
  vim.deep_equal(vim.api.nvim_buf_get_lines(slow_buf, 0, -1, false), { "#  遅い" }),
  "遅れた結果は当てない"
)
assert(vim.deep_equal(slow_lines, { "#  遅い" }))

-- 先に読み込んだ整形器 (format.mjs) が変わったら、その予備は使わずに止め、CLI で整形する。
-- 導入先の写し (整形器の .mjs と導入の記録。依存は本物の導入先へのリンク) を作って使う。
local copied_source = vim.fs.joinpath(sandbox, "install-copy")
vim.fn.mkdir(copied_source, "p")
for name, kind in vim.fs.dir(install_dir) do
  if kind == "file" and (name:match("%.mjs$") or name:match("%.json$")) then
    assert(uv.fs_copyfile(vim.fs.joinpath(install_dir, name), vim.fs.joinpath(copied_source, name)))
  end
end
assert(
  uv.fs_symlink(
    vim.fs.joinpath(install_dir, "node_modules"),
    vim.fs.joinpath(copied_source, "node_modules"),
    { junction = true, dir = true }
  )
)
md_format.install_dir = function()
  return copied_source
end
spare.stop()
spare.start()
local stale_pid = spare.pid()
assert(stale_pid and spare.usable())
local copied_format = vim.fs.joinpath(copied_source, "format.mjs")
vim.fn.writefile(vim.list_extend(vim.fn.readfile(copied_format), { "// 変えた" }), copied_format)
assert(not spare.usable(), "整形器が変わった予備は使わない")
assert(vim.wait(1500, function()
  return not alive(stale_pid)
end, 20))
local stale_buf = buffer({ "#  変えた後" })
local stale_result, stale_lines = format(stale_buf, { formatters = { "mdfmt_spare_test" } })
assert(not stale_result.err and stale_lines[1] == "# 変えた後", vim.inspect(stale_result))
-- 予備が要求を受け付けなかったら (終了コード 86・出力なし)、CLI でやり直す。
spare.stop()
vim.fn.writefile({
  "process.stdin.resume();",
  "process.stdin.on('end', () => { process.exitCode = 86; });",
}, vim.fs.joinpath(copied_source, "spare.mjs"))
spare.start()
local refused_buf = buffer({ "#  受け付けない" })
local refused_result, refused_lines, refused_via_spare =
  format(refused_buf, { formatters = { "mdfmt_spare_test" } }, true)
assert(refused_via_spare and not refused_result.err, vim.inspect(refused_result))
assert(vim.deep_equal(refused_lines, { "# 受け付けない" }))
spare.stop()
md_format.install_dir = install_dir_function

-- 待っている間に外から止められた予備は使わずに CLI で整形し、次の保存のために起動し直す。
-- 前の整形が予約した起動 (100 ms 後) が済んでから止める (その予約で起動し直したのでは確かめにならない)。
spare.start()
vim.wait(300)
local killed_pid = spare.pid()
assert(killed_pid)
uv.kill(killed_pid, "sigterm")
assert(
  vim.wait(1500, function()
    return spare.pid() == nil
  end, 20),
  "止められた予備を捨てる"
)
local killed_buf = buffer({ "#  止められた後" })
local killed_result, killed_lines, killed_via_spare = format(killed_buf, { formatters = { "mdfmt_spare_test" } }, true)
assert(not killed_via_spare and not killed_result.err, vim.inspect(killed_result))
assert(vim.deep_equal(killed_lines, { "# 止められた後" }))
assert(
  vim.wait(1500, function()
    return spare.pid() ~= nil
  end, 20),
  "次の保存のために起動し直す"
)

-- node の実体・環境変数が変わったら、その予備は使わない。
assert(spare.usable())
local exepath = vim.fn.exepath
vim.fn.exepath = function(name)
  return name == "node" and vim.fs.joinpath(sandbox, "別の node.exe") or exepath(name)
end
assert(not spare.usable(), "node が変わった予備は使わない")
vim.fn.exepath = exepath
spare.start()
assert(spare.usable())
vim.env.MD_FORMAT_SPARE_TEST = "変えた"
assert(not spare.usable(), "環境変数が変わった予備は使わない")
vim.env.MD_FORMAT_SPARE_TEST = nil

-- 非同期の整形も予備を通って終わり、上限を過ぎたときも conform に時間切れを返す (止まったままにならない)。
spare.start()
local async_buf = buffer({ "#  非同期" })
local async_done
conform.format(
  { bufnr = async_buf, async = true, quiet = true, formatters = { "mdfmt_spare_test" } },
  function(err, edited)
    async_done = { err = err, edited = edited }
  end
)
assert(vim.wait(5000, function()
  return async_done ~= nil
end, 20))
assert(not async_done.err and async_done.edited, vim.inspect(async_done))
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(async_buf, 0, -1, false), { "# 非同期" }))
spare.start()
local async_slow_buf = buffer({ "#  遅い非同期" })
vim.api.nvim_buf_set_name(async_slow_buf, vim.fs.joinpath(slow, "非同期.md"))
local async_slow
conform.format(
  { bufnr = async_slow_buf, async = true, quiet = true, formatters = { "mdfmt_spare_slow" } },
  function(err)
    async_slow = { err = err }
  end
)
assert(
  vim.wait(3000, function()
    return async_slow ~= nil
  end, 20),
  "非同期でも上限で終わる"
)
assert(async_slow.err and async_slow.err:lower():find("timeout", 1, true), vim.inspect(async_slow))
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(async_slow_buf, 0, -1, false), { "#  遅い非同期" }))

-- Markdown のバッファをすべて閉じると予備を止め、また開くと起動する。
local closing_pid = spare.pid()
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.bo[buf].filetype == "markdown" then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end
assert(spare.pid() == nil)
assert(vim.wait(1500, function()
  return not alive(closing_pid)
end, 20))
local reopened = buffer({ "# また開く" })
assert(spare.pid(), "Markdown を開くと起動する")
-- filetype を Markdown からほかに変えて Markdown のバッファが無くなったら止め、戻すと起動する。
local text_pid = spare.pid()
vim.bo[reopened].filetype = "text"
assert(spare.pid() == nil)
assert(vim.wait(1500, function()
  return not alive(text_pid)
end, 20))
vim.bo[reopened].filetype = "markdown"
assert(spare.pid(), "Markdown に戻すと起動する")

-- Neovim の終了で予備を止める。
local leaving_pid = spare.pid()
vim.api.nvim_exec_autocmds("VimLeavePre", {})
assert(spare.pid() == nil)
assert(vim.wait(1500, function()
  return not alive(leaving_pid)
end, 20))
spare.setup({ enabled = false })

-- format_dir (setup の dir) の相対パスは、setup のときの作業フォルダから解く。後で :cd しても導入先は変わらない。
md_format.install_dir = original_install_dir
local saved_cwd = uv.cwd()
vim.cmd.cd(vim.fs.dirname(install_dir))
md_format.setup({ spare = false, dir = vim.fs.basename(install_dir) })
vim.cmd.cd(sandbox)
assert(md_format.install_dir() == vim.fs.normalize(install_dir), md_format.install_dir())
assert(md_format.installed())
vim.cmd.cd(saved_cwd)

vim.fn.delete(sandbox, "rf")
print("md-format conform integration: PASS")
