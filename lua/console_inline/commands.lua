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

	vim.api.nvim_create_user_command("ConsoleInlinePopup", function()
		local entry = render.get_entry_at_cursor()
		if not entry then
			vim.notify("console-inline: no message at cursor", vim.log.levels.WARN)
			return
		end
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
		local lines = vim.split(entry.payload or entry.text or "", "\n", true)
		if entry.count and entry.count > 1 then
			table.insert(lines, 1, string.format("[%dx repeats]", entry.count))
		end
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		local width = 0
		for _, line in ipairs(lines) do
			width = math.max(width, vim.fn.strdisplaywidth(line))
		end
		width = math.min(math.max(width + 4, 40), math.floor(vim.o.columns * 0.8))
		local height = math.min(#lines, math.floor(vim.o.lines * 0.5))
		local opts = {
			relative = "cursor",
			row = 1,
			col = 0,
			width = width,
			height = math.max(height, 1),
			style = "minimal",
			border = "rounded",
		}
		local win = vim.api.nvim_open_win(buf, true, opts)
		vim.api.nvim_buf_set_option(buf, "modifiable", false)
		vim.keymap.set("n", "q", function()
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end, { buffer = buf, nowait = true })
		vim.keymap.set("n", "<Esc>", function()
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end, { buffer = buf, nowait = true })
	end, {})
end
