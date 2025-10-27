local server = require("console_inline.server")
local render = require("console_inline.render")

return function()
	local state = require("console_inline.state")

	vim.api.nvim_create_user_command("ConsoleInlineStatus", function()
		local running = state.running and "running" or "stopped"
		local host = state.opts.host or "127.0.0.1"
		local port = state.opts.port or 36123
		local sockets = state.sockets and #state.sockets or 0
		vim.notify(
			string.format("console-inline: TCP server is %s on %s:%d (%d active sockets)", running, host, port, sockets)
		)
	end, {})
	vim.api.nvim_create_user_command("ConsoleInlineToggle", function()
		server.toggle()
	end, {})

	vim.api.nvim_create_user_command("ConsoleInlineClear", function()
		render.clear_current_buffer()
	end, {})

	vim.api.nvim_create_user_command("ConsoleInlineCopy", function()
		render.copy_current_line()
	end, {})
end
