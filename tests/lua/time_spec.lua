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

	local function find_entry(buf)
		local map = state.last_msg_by_buf_line[buf]
		if not map then
			return nil
		end
		for _, value in pairs(map) do
			if value then
				return value
			end
		end
		return nil
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
		local entry = find_entry(buf)
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
		local entry = find_entry(buf)
		assert.is_truthy(entry)
		assert.are.equal("missing", entry.time.label)
		assert.is_truthy(entry.text:find("not found", 1, true))
	end)
end)
