-- 実行: nvim --headless -u NONE -i NONE -l tests/mdtable_edit.lua
-- lazy.nvim・Excel・mdtable を起動せず、コマンドと引数・保存・失敗時の通知を確かめる。
local source = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(source)))
vim.opt.runtimepath:prepend(root)
vim.o.swapfile = false
local uv = vim.uv or vim.loop
local sandbox = vim.fs.joinpath(root, ".tests", "mdtable-edit-" .. uv.os_getpid())
vim.fn.mkdir(sandbox, "p")

local original = { has = vim.fn.has, exepath = vim.fn.exepath, notify = vim.notify, snacks = _G.Snacks }
local buffers, notifications, terminals = {}, {}, {}
vim.notify = function(message, level)
  notifications[#notifications + 1] = { message = message, level = level }
end
_G.Snacks = {
  terminal = function(command, options)
    assert(not vim.bo.modified, "端末を開く前に保存を終える")
    assert(vim.deep_equal(vim.fn.readfile(command[3]), vim.api.nvim_buf_get_lines(0, 0, -1, false)))
    terminals[#terminals + 1] = { command = command, options = options }
  end,
}
local function buffer(name, lines)
  local buf = vim.api.nvim_create_buf(true, false)
  buffers[#buffers + 1] = buf
  vim.api.nvim_set_current_buf(buf)
  if name then
    vim.api.nvim_buf_set_name(buf, name)
  end
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or { "本文" })
  return buf
end

local ok, err = xpcall(function()
  local spec_path = vim.fs.joinpath(root, "lua", "plugins", "mdtable.lua")
  -- 実際の OS と、差し替えた両方の OS 判定で spec を確かめる。
  local native_specs = dofile(spec_path)
  assert(#native_specs == (original.has("win32") == 1 and 1 or 0))
  vim.fn.has = function(feature)
    return feature == "win32" and 0 or original.has(feature)
  end
  assert(vim.deep_equal(dofile(spec_path), {}), "Windows 以外では spec を返さない")
  vim.fn.has = function(feature)
    return feature == "win32" and 1 or original.has(feature)
  end
  local specs = dofile(spec_path)
  vim.fn.has = original.has
  assert(#specs == 1)
  local spec = specs[1]
  assert(spec[1] == "mdtable-edit" and spec.virtual == true)
  assert(vim.deep_equal(spec.cmd, { "MdTableEdit" }))
  assert(#spec.keys == 1)
  local key = spec.keys[1]
  assert(key[1] == "<leader>te" and key[2] == "<cmd>MdTableEdit<cr>")
  assert(key.ft == "markdown" and key.desc == "表を Excel で編集 (mdtable)")
  assert(package.loaded["config.mdtable"] == nil, "spec だけでは実体を読み込まない")
  assert(vim.fn.exists(":MdTableEdit") == 0)
  spec.config()
  assert(vim.fn.exists(":MdTableEdit") == 2)
  assert(package.loaded["config.mdtable"] == nil, "コマンドの登録だけでも実体を読み込まない")

  local executable = vim.fs.joinpath(sandbox, "道具 の置き場", "mdtable.exe")
  vim.fn.exepath = function(name)
    assert(name == "mdtable")
    return executable
  end
  local filename = vim.fs.joinpath(sandbox, "空白 のある文書.md")
  local lines = { "# 見出し", "", "| 名前 | 値 |", "| --- | --- |", "| 項目 | 編集 |" }
  local buf = buffer(filename, lines)
  vim.api.nvim_win_set_cursor(0, { 5, 0 })
  assert(vim.bo[buf].modified and vim.fn.filereadable(filename) == 0)
  local mdtable = require("config.mdtable")
  mdtable.edit()
  assert(not vim.bo[buf].modified, "未保存の変更を保存する")
  assert(vim.deep_equal(vim.fn.readfile(filename), lines), "端末を開く前に本文をファイルに書く")
  local expected = { executable, "edit", vim.fn.fnamemodify(filename, ":p"), "--table", "L5" }
  assert(#terminals == 1 and vim.deep_equal(terminals[1].command, expected), vim.inspect(terminals))
  assert(terminals[1].options == nil, "成功・失敗時の動作は Snacks.terminal の既定に任せる")
  assert(#notifications == 0)

  -- 保存済みのバッファは書き直さず、利用者コマンドからも同じ引数で呼べる。
  local writes = 0
  local group = vim.api.nvim_create_augroup("mdtable_edit_test", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    buffer = buf,
    callback = function()
      writes = writes + 1
    end,
  })
  vim.cmd.MdTableEdit()
  assert(#terminals == 2 and vim.deep_equal(terminals[2].command, expected))
  assert(writes == 0 and #notifications == 0)
  vim.api.nvim_del_augroup_by_id(group)

  buffer(nil)
  mdtable.edit()
  assert(#terminals == 2 and #notifications == 1)
  assert(notifications[1].level == vim.log.levels.ERROR)
  assert(notifications[1].message:find("保存してから", 1, true))

  local missing_file = vim.fs.joinpath(sandbox, "未導入 の文書.md")
  local missing_buf = buffer(missing_file)
  vim.fn.exepath = function(name)
    assert(name == "mdtable")
    return ""
  end
  mdtable.edit()
  assert(#terminals == 2 and #notifications == 2)
  assert(vim.bo[missing_buf].modified and vim.fn.filereadable(missing_file) == 0)
  local missing = notifications[2]
  assert(missing.level == vim.log.levels.ERROR)
  assert(missing.message:find("Windows 11 で mdtable を導入・更新する", 1, true))
  local install_url = "https://github.com/ryo-aoki-pc/md-table-excel/blob/main/docs/install.md"
    .. "#windows-11-で-mdtable-を導入更新する"
  assert(missing.message:find(install_url, 1, true))

  -- 保存できないバッファでは、変更を保ったまま通知し、端末を開かない。
  vim.fn.exepath = function()
    return executable
  end
  local readonly_file = vim.fs.joinpath(sandbox, "保存 できない.md")
  local readonly_buf = buffer(readonly_file)
  vim.bo[readonly_buf].readonly = true
  mdtable.edit()
  assert(#terminals == 2 and #notifications == 3)
  assert(vim.bo[readonly_buf].modified and vim.fn.filereadable(readonly_file) == 0)
  assert(notifications[3].level == vim.log.levels.ERROR)
  assert(notifications[3].message:find("保存に失敗", 1, true))
end, debug.traceback)

vim.fn.has, vim.fn.exepath, vim.notify, _G.Snacks = original.has, original.exepath, original.notify, original.snacks
for _, buf in ipairs(buffers) do
  vim.api.nvim_buf_delete(buf, { force = true })
end
assert(vim.fs.normalize(sandbox):sub(1, #root + 8) == root .. "/.tests/", "片付けは作業ツリー内だけ")
vim.fn.delete(sandbox, "rf")
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
end
print("mdtable edit integration: PASS")
