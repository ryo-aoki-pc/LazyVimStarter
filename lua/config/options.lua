-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.fileencodings = { "utf-8", "cp932", "euc-jp", "utf-16le" }
vim.opt.guifont = "HackGen Console NF:h12"
vim.opt.relativenumber = false
vim.opt.wildmode = { "longest", "list" }

if vim.fn.has("win32") == 1 then
	vim.opt.shell = "powershell"
	vim.opt.shellcmdflag = "-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command"
	vim.opt.shellquote = ""
	vim.opt.shellxquote = ""
	vim.opt.shellredir = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode"
	vim.opt.shellpipe = "2>&1 | Tee-Object %s; exit $LastExitCode"
end
