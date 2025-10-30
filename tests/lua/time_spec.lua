local render = require("console_inline.render")
local history = require("console_inline.history")
local state = require("console_inline.state")
local format = require("console_inline.format")

describe("timer messages", function()
	local function ensure_named_buffer()
		local buf = vim.api.nvim_get_current_buf()
		local file = vim.api.nvim_buf_get_name(buf)
		if file == "" then
			file = vim.fn.tempname()
			vim.api.nvim_buf_set_name(buf, file)
		end
		return buf, file
	end

	before_each(function()
		history.clear()
		state.extmarks_by_buf_line = {}
		state.last_msg_by_buf_line = {}
		state.queued_messages_by_file = {}
	end)

	it("renders timing duration inline", function()
		local buf, file = ensure_named_buffer()
		render.render_message({
			file = file,
			line = 10,
			method = "timeEnd",
			kind = "log",
			args = {},
			time = { label = "fetch", duration_ms = 12.345, kind = "timeEnd" },
		})
		local entry = state.last_msg_by_buf_line[buf] and state.last_msg_by_buf_line[buf][10]
		assert.is_truthy(entry)
		assert.are.same("fetch", entry.time.label)
		assert.is_truthy(entry.text:find("fetch", 1, true))
		assert.is_truthy(entry.text:find("12.345", 1, true))
		local lines = format.default(entry)
		assert.is_truthy(lines[#lines]:find("12.345", 1, true))
	end)

	it("handles missing timer gracefully", function()
		local buf, file = ensure_named_buffer()
		render.render_message({
			file = file,
			line = 5,
			method = "timeEnd",
			kind = "log",
			args = {},
			time = { label = "missing", missing = true, kind = "timeEnd" },
		})
		local entry = state.last_msg_by_buf_line[buf] and state.last_msg_by_buf_line[buf][5]
		assert.is_truthy(entry)
		assert.are.equal("missing", entry.time.label)
		assert.is_truthy(entry.text:find("not found", 1, true))
	end)
end)
