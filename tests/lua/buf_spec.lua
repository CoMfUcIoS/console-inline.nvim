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

local buf_utils = require("console_inline.buf")

describe("buf helpers", function()
	local tmpfiles = {}

	after_each(function()
		for _, file in ipairs(tmpfiles) do
			os.remove(file)
		end
		tmpfiles = {}
	end)

	it("finds buffer by exact path", function()
		local buf = vim.api.nvim_create_buf(false, true)
		local name = vim.fn.tempname()
		tmpfiles[#tmpfiles + 1] = name
		vim.api.nvim_buf_set_name(buf, name)
		local found = buf_utils.find_buf_by_path(name)
		assert.are.equal(buf, found)
	end)

	it("falls back to tail match", function()
		local buf = vim.api.nvim_create_buf(false, true)
		local name = vim.fn.tempname()
		tmpfiles[#tmpfiles + 1] = name
		vim.api.nvim_buf_set_name(buf, name)
		local tail = name:match("[^/\\]+$")
		local other = "/tmp/" .. tail
		local found = buf_utils.find_buf_by_path(other)
		assert.are.equal(buf, found)
	end)

	it("ensures buffer exists", function()
		local name = vim.fn.tempname()
		tmpfiles[#tmpfiles + 1] = name
		local buf = buf_utils.ensure_buffer(name)
		assert.is_truthy(buf)
		assert.are.equal(name, vim.api.nvim_buf_get_name(buf))
	end)
end)
