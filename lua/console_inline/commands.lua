local server = require("console_inline.server")
local render = require("console_inline.render")

return function()
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
