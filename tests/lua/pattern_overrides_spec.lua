local render = require("console_inline.render")
local state = require("console_inline.state")
local history = require("console_inline.history")

describe("pattern overrides", function()
	local original_overrides

	before_each(function()
		original_overrides = state.opts.pattern_overrides
		state.opts.pattern_overrides = nil
		history.clear()
		state.extmarks_by_buf_line = {}
		state.last_msg_by_buf_line = {}
		state.queued_messages_by_file = {}
	end)

	after_each(function()
		state.opts.pattern_overrides = original_overrides
	end)

	it("applies custom icon and highlight", function()
		local buf = vim.api.nvim_get_current_buf()
		local file = vim.api.nvim_buf_get_name(buf)
		if file == "" then
			file = vim.fn.tempname()
			vim.api.nvim_buf_set_name(buf, file)
		end
		state.opts.pattern_overrides = {
			{ pattern = "TODO", icon = "📝", highlight = "Todo" },
		}
		render.render_message({ file = file, line = 1, kind = "log", args = { "TODO something" } })
		local entry = state.last_msg_by_buf_line[buf] and state.last_msg_by_buf_line[buf][0]
		assert.is_truthy(entry)
		assert.are.equal("📝", entry.icon)
		assert.are.equal("Todo", entry.highlight)
		local hist = history.entries()[1]
		assert.are.equal("📝", hist.icon)
		assert.are.equal("Todo", hist.highlight)
	end)

	it("uses default patterns when overrides unset", function()
		local buf = vim.api.nvim_get_current_buf()
		local file = vim.api.nvim_buf_get_name(buf)
		if file == "" then
			file = vim.fn.tempname()
			vim.api.nvim_buf_set_name(buf, file)
		end
		state.opts.pattern_overrides = nil
		render.render_message({ file = file, line = 1, kind = "log", args = { "TODO: implement" } })
		local entry = state.last_msg_by_buf_line[buf] and state.last_msg_by_buf_line[buf][0]
		assert.is_truthy(entry)
		assert.are.equal("📝", entry.icon)
		assert.are.equal("Todo", entry.highlight)
	end)

	it("supports plain string matches", function()
		local buf = vim.api.nvim_get_current_buf()
		local file = vim.api.nvim_buf_get_name(buf)
		if file == "" then
			file = vim.fn.tempname()
			vim.api.nvim_buf_set_name(buf, file)
		end
		state.opts.pattern_overrides = {
			{ pattern = "literal.+pattern", icon = "⭐" },
			{ pattern = "just text", icon = "✔", plain = true },
		}
		render.render_message({ file = file, line = 1, kind = "info", args = { "just text" } })
		local entry = state.last_msg_by_buf_line[buf] and state.last_msg_by_buf_line[buf][0]
		assert.is_truthy(entry)
		assert.are.equal("✔", entry.icon)
	end)
end)
