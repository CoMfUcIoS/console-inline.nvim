local render = require("console_inline.render")

describe("render basics", function()
	it("does not crash on minimal message", function()
		assert.has_no.errors(function()
			render.render_message({ file = vim.api.nvim_buf_get_name(0), line = 1, kind = "log", args = { "x" } })
		end)
	end)
end)
