-- Copyright (c) 2025 Ioannis Karasavvaidis
-- This file is part of console-inline.nvim
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

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
