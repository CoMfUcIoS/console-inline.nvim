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
		state.opts.history_size = 200
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

	it("trims according to history_size", function()
		state.opts.history_size = 2
		history.record({ file = "a", icon = "●" })
		history.record({ file = "b", icon = "●" })
		history.record({ file = "c", icon = "●" })
		local entries = history.entries()
		assert.are.equal(2, #entries)
		assert.are.equal("c", entries[1].file)
		assert.are.equal("b", entries[2].file)
	end)
end)
