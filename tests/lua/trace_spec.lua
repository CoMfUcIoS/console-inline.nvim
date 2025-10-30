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
local state = require("console_inline.state")
local format = require("console_inline.format")

describe("trace messages", function()
	local function prepare_buffer()
		local buf = vim.api.nvim_get_current_buf()
		local name = vim.api.nvim_buf_get_name(buf)
		if name == "" then
			name = vim.fn.tempname()
			vim.api.nvim_buf_set_name(buf, name)
		end
		return buf, name
	end

	before_each(function()
		history.clear()
		state.extmarks_by_buf_line = {}
		state.last_msg_by_buf_line = {}
		state.queued_messages_by_file = {}
	end)

	it("stores trace frames in entries and history", function()
		local buf, file = prepare_buffer()
		render.render_message({
			file = file,
			line = 1,
			kind = "log",
			method = "trace",
			args = {},
			trace = { "app.js:10:5", "lib.js:2:3" },
		})
		local entry = state.last_msg_by_buf_line[buf] and state.last_msg_by_buf_line[buf][0]
		assert.is_truthy(entry)
		assert.are.same({ "app.js:10:5", "lib.js:2:3" }, entry.trace)
		local hist = history.entries()[1]
		assert.are.same(entry.trace, hist.trace)
		assert.is_truthy(entry.text:find("app.js:10:5", 1, true))
	end)

	it("formatter appends trace information", function()
		local lines = format.default({
			raw_args = {},
			trace = { "service.ts:5:1" },
			text = "trace",
		})
		assert.are.equal("[trace 1] service.ts:5:1", lines[#lines])
	end)
end)
