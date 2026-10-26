-- -u NONE -i NONE -l で使い、lazy.nvim の導入や通常の設定は起動しない。
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(debug.getinfo(1, "S").source:sub(2))))
vim.opt.runtimepath:prepend(root)
local opts = { wait = true }
local args = _G.arg or {}
for i = 1, #args do
  if args[i] == "--data-dir" then
    opts.data_dir = args[i + 1]
    assert(opts.data_dir and opts.data_dir ~= "", "--data-dir に保存先が必要")
  elseif i == 1 or args[i - 1] ~= "--data-dir" then
    error("不明な引数: " .. tostring(args[i]))
  end
end
local ok, message = require("config.gitlab_preview.installer").run(opts)
if not ok then
  io.stderr:write("GitLab プレビューの公式スタイル: " .. tostring(message) .. "\n")
  vim.cmd("cquit 1")
end
print("GitLab プレビューの公式スタイル: 導入済み")
