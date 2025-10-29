local render = require("console_inline.render")
local history = require("console_inline.history")

describe("render basics", function()
	before_each(function()
		history.clear()
		local state = require("console_inline.state")
		state.extmarks_by_buf_line = {}
		state.last_msg_by_buf_line = {}
		state.queued_messages_by_file = {}
	end)
	it("does not crash on minimal message", function()
		assert.has_no.errors(function()
			render.render_message({ file = vim.api.nvim_buf_get_name(0), line = 1, kind = "log", args = { "x" } })
		end)
	end)

	it("skips remote paths", function()
		render.render_message({ file = "http://example.com/app.js", line = 1, kind = "log", args = { "remote" } })
		local hist = require("console_inline.history").entries()
		assert.are.equal(0, #hist)
	end)
end)
