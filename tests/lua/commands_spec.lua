local state = require("console_inline.state")

describe("user commands", function()
	local server_stub
	local render_stub
	local history_entries
	local history_stub
	local original_modules = {}
	local notify_calls
	local original_notify

	local function reset_history(entries)
		history_entries = entries or {}
	end

	before_each(function()
		original_modules.server = package.loaded["console_inline.server"]
		original_modules.render = package.loaded["console_inline.render"]
		original_modules.history = package.loaded["console_inline.history"]

		server_stub = {
			start_calls = 0,
			stop_calls = 0,
			toggle_calls = 0,
		}
		function server_stub.start()
			server_stub.start_calls = server_stub.start_calls + 1
		end
		function server_stub.stop()
			server_stub.stop_calls = server_stub.stop_calls + 1
		end
		function server_stub.toggle()
			server_stub.toggle_calls = server_stub.toggle_calls + 1
		end
		package.loaded["console_inline.server"] = server_stub

		render_stub = {
			clear_calls = 0,
			copy_calls = 0,
			entry = nil,
		}
		function render_stub.clear_current_buffer()
			render_stub.clear_calls = render_stub.clear_calls + 1
		end
		function render_stub.copy_current_line()
			render_stub.copy_calls = render_stub.copy_calls + 1
		end
		function render_stub.get_entry_at_cursor()
			return render_stub.entry
		end
		package.loaded["console_inline.render"] = render_stub

		reset_history()
		history_stub = {
			is_empty = function()
				return #history_entries == 0
			end,
			entries = function()
				return history_entries
			end,
			record = function(entry)
				table.insert(history_entries, entry)
			end,
			clear = function()
				history_entries = {}
			end,
		}
		package.loaded["console_inline.history"] = history_stub

		notify_calls = {}
		original_notify = vim.notify
		vim.notify = function(msg, level)
			notify_calls[#notify_calls + 1] = { msg = msg, level = level }
		end

		for _, name in ipairs({
			"ConsoleInlineToggle",
			"ConsoleInlineClear",
			"ConsoleInlineCopy",
			"ConsoleInlinePopup",
			"ConsoleInlineHistory",
		}) do
			pcall(vim.api.nvim_del_user_command, name)
		end

		require("console_inline.commands")()
		state.opts.popup_formatter = function(entry)
			return { entry.payload or entry.text or "" }
		end
	end)

	after_each(function()
		package.loaded["console_inline.server"] = original_modules.server
		package.loaded["console_inline.render"] = original_modules.render
		package.loaded["console_inline.history"] = original_modules.history
		vim.notify = original_notify
	end)

	it("toggles server", function()
		vim.cmd("ConsoleInlineToggle")
		assert.are.equal(1, server_stub.toggle_calls)
	end)

	it("clears current buffer", function()
		vim.cmd("ConsoleInlineClear")
		assert.are.equal(1, render_stub.clear_calls)
	end)

	it("copies current line", function()
		vim.cmd("ConsoleInlineCopy")
		assert.are.equal(1, render_stub.copy_calls)
	end)

	it("warns when popup has no entry", function()
		render_stub.entry = nil
		vim.cmd("ConsoleInlinePopup")
		assert.is_true(#notify_calls >= 1)
		assert.are.equal(vim.log.levels.WARN, notify_calls[#notify_calls].level)
	end)

	it("warns when history empty", function()
		history_entries = {}
		vim.cmd("ConsoleInlineHistory")
		assert.is_true(#notify_calls >= 1)
		assert.are.equal(vim.log.levels.WARN, notify_calls[#notify_calls].level)
	end)

	it("errors when telescope missing", function()
		reset_history({ { file = "file", render_line = 1, icon = "●", display = "message" } })
		package.loaded.telescope = nil
		vim.cmd("ConsoleInlineHistory")
		assert.is_true(#notify_calls >= 1)
		assert.are.equal(vim.log.levels.ERROR, notify_calls[#notify_calls].level)
	end)
end)
