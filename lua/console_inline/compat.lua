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

local M = {}

function M.supports_right_align()
	local ok = pcall(function()
		vim.api.nvim_buf_set_extmark(0, vim.api.nvim_create_namespace("console_inline_probe"), 0, 0, {
			id = 999999,
			virt_text = { { "" } },
			virt_text_pos = "eol_right_align",
		})
	end)
	return ok
end

return M
