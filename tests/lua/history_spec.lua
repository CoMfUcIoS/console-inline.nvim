local history = require("console_inline.history")
local render = require("console_inline.render")
local state = require("console_inline.state")
local buf_utils = require("console_inline.buf")

describe("history tracking", function()
	before_each(function()
		history.clear()
		state.extmarks_by_buf_line = {}
		state.last_msg_by_buf_line = {}
		state.queued_messages_by_file = {}
	end)

	it("records messages rendered in the active buffer", function()
		local buf = vim.api.nvim_get_current_buf()
		local file = vim.api.nvim_buf_get_name(buf)
		if file == "" then
			file = vim.fn.tempname()
			vim.api.nvim_buf_set_name(buf, file)
		end
		render.render_message({ file = file, line = 1, kind = "log", args = { "alpha" } })
		assert.are.equal(1, #history.entries())
		local entry = history.entries()[1]
		assert.are.equal(file, entry.file)
	end)

	it("records queued messages once", function()
		local tmpfile = vim.fn.tempname()
		vim.fn.writefile({ "queued" }, tmpfile)
		local msg = { file = tmpfile, line = 2, kind = "log", args = { "queued" } }
		render.render_message(msg)
		assert.are.equal(1, #history.entries())
		local key = buf_utils.canon(tmpfile)
		assert.is_truthy(state.queued_messages_by_file[key])
		buf_utils.ensure_buffer(tmpfile)
		render.render_message(msg)
		assert.are.equal(1, #history.entries())
	end)
end)
