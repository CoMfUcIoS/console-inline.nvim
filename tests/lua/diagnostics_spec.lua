-- Copyright (c) 2025 Ioannis Karasavvaidis
-- GPL-3.0-or-later

local state = require("console_inline.state")
local render = require("console_inline.render")

describe("diagnostics command map stats", function()
	local notify_calls
	local original_notify

	before_each(function()
		notify_calls = {}
		original_notify = vim.notify
		vim.notify = function(msg, level)
			notify_calls[#notify_calls + 1] = { msg = msg, level = level }
		end
		-- reset state map stats
		state.map_stats.hit = 0
		state.map_stats.miss = 0
		state.map_stats.pending = 0
		-- ensure commands registered
		require("console_inline.init").setup({ autostart = false })
	end)

	after_each(function()
		vim.notify = original_notify
	end)

	it("reports updated map stats after rendering messages", function()
		local buf = vim.api.nvim_get_current_buf()
		local name = vim.api.nvim_buf_get_name(buf)
		if name == "" then
			name = vim.fn.tempname()
			vim.api.nvim_buf_set_name(buf, name)
		end
		-- render a hit
		render.render_message({ file = name, line = 1, kind = "log", method = "log", args = {}, mapping_status = "hit" })
		-- render a miss
		render.render_message({
			file = name,
			line = 2,
			kind = "log",
			method = "log",
			args = {},
			mapping_status = "miss",
		})
		-- render a pending
		render.render_message({
			file = name,
			line = 3,
			kind = "log",
			method = "log",
			args = {},
			mapping_status = "pending",
		})

		vim.cmd("ConsoleInlineDiagnostics")
		assert.is_true(#notify_calls > 0)
		local last = notify_calls[#notify_calls].msg
		assert.is_truthy(last:find("source map hits=1 misses=1 pending=1", 1, true))
	end)
end)
