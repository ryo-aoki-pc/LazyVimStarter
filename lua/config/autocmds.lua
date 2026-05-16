-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local skkeleton_group = vim.api.nvim_create_augroup("skkeleton_setup", { clear = true })

vim.api.nvim_create_autocmd("User", {
	group = skkeleton_group,
	pattern = "skkeleton-initialize-pre",
	callback = function()
		require("config.skkeleton").apply_config()
	end,
})

vim.api.nvim_create_autocmd("VimEnter", {
	group = skkeleton_group,
	once = true,
	callback = function()
		require("config.skkeleton").warn_if_dictionary_missing()
	end,
})
