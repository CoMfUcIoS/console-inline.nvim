local ok, mod = pcall(require, "console_inline")
if not ok then
	vim.schedule(function()
		vim.notify("console-inline.nvim: failed to load module", vim.log.levels.ERROR)
	end)
	return
end

if not vim.g.console_inline_lazy_setup_done then
	mod.setup({})
end
