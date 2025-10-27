local state = require("console_inline.state")
local server = require("console_inline.server")

local M = {}

function M.setup(opts)
	if vim.g.console_inline_lazy_setup_done then
		return
	end
	state.opts = vim.tbl_deep_extend("force", state.opts, opts or {})
	require("console_inline.commands")()
	vim.api.nvim_create_autocmd("VimEnter", {
		once = true,
		callback = function()
			server.start()
		end,
	})
	vim.g.console_inline_lazy_setup_done = true
end

function M.start(...)
	return server.start(...)
end
function M.stop(...)
	return server.stop(...)
end
function M.toggle(...)
	return server.toggle(...)
end

return M
