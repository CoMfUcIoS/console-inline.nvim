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
local state = require("console_inline.state")
local history = require("console_inline.history")

describe("project filters", function()
	local original_filters

	local function ensure_named_buffer()
		local buf = vim.api.nvim_get_current_buf()
		local name = vim.api.nvim_buf_get_name(buf)
		if name == "" then
			name = vim.fn.tempname()
			vim.api.nvim_buf_set_name(buf, name)
		end
		return buf, name
	end

	before_each(function()
		original_filters = state.opts.filters
		state.opts.filters = nil
		history.clear()
		state.extmarks_by_buf_line = {}
		state.last_msg_by_buf_line = {}
		state.queued_messages_by_file = {}
	end)

	after_each(function()
		state.opts.filters = original_filters
	end)

	it("denies messages by path glob", function()
		local buf, file = ensure_named_buffer()
		state.opts.filters = {
			deny = {
				paths = { file },
			},
		}
		render.render_message({ file = file, line = 1, kind = "log", args = { "denied" } })
		assert.is_nil(state.last_msg_by_buf_line[buf])
		assert.are.equal(0, #history.entries())
	end)

	it("allows only configured paths", function()
		local buf, file = ensure_named_buffer()
		local allow_glob = vim.fn.fnamemodify(file, ":h") .. "/**"
		state.opts.filters = {
			allow = {
				paths = { allow_glob },
			},
		}
		render.render_message({ file = file, line = 1, kind = "log", args = { "kept" } })
		assert.is_truthy(state.last_msg_by_buf_line[buf])
		state.last_msg_by_buf_line = {}
		render.render_message({ file = "/tmp/other_file.js", line = 1, kind = "log", args = { "filtered" } })
		assert.is_nil(state.last_msg_by_buf_line[buf])
	end)

	it("filters by message pattern", function()
		local buf, file = ensure_named_buffer()
		state.opts.filters = {
			deny = {
				messages = { { pattern = "noise", plain = true } },
			},
		}
		render.render_message({ file = file, line = 1, kind = "log", args = { "noise event" } })
		assert.is_nil(state.last_msg_by_buf_line[buf])
		render.render_message({ file = file, line = 1, kind = "log", args = { "signal" } })
		assert.is_truthy(state.last_msg_by_buf_line[buf])
	end)

	it("adjusts severity per rule", function()
		local buf, file = ensure_named_buffer()
		state.opts.filters = {
			severity = {
				{
					paths = { file },
					allow = { log = false, warn = true },
				},
			},
		}
		render.render_message({ file = file, line = 1, kind = "log", args = { "hidden" } })
		assert.is_nil(state.last_msg_by_buf_line[buf])
		render.render_message({ file = file, line = 1, kind = "warn", args = { "visible" } })
		assert.is_truthy(state.last_msg_by_buf_line[buf])
	end)

	it("supports severity only lists", function()
		local buf, file = ensure_named_buffer()
		state.opts.filters = {
			severity = {
				{
					paths = { file },
					only = { "error", "warn" },
				},
			},
		}
		render.render_message({ file = file, line = 1, kind = "log", args = { "suppressed" } })
		assert.is_nil(state.last_msg_by_buf_line[buf])
		render.render_message({ file = file, line = 1, kind = "error", args = { "kept" } })
		assert.is_truthy(state.last_msg_by_buf_line[buf])
	end)
end)
