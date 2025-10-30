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

local function to_boolean(value)
	if value == nil then
		return nil
	end
	if type(value) == "boolean" then
		return value
	end
	if type(value) == "number" then
		return value ~= 0
	end
	if type(value) == "string" then
		local lower = value:lower()
		if lower == "" or lower == "0" or lower == "false" or lower == "off" then
			return false
		end
		return true
	end
	return true
end

local cached
local function compute_debug_enabled()
	if cached ~= nil then
		return cached
	end
	if vim.g.console_inline_debug ~= nil then
		cached = to_boolean(vim.g.console_inline_debug)
		return cached
	end
	local ok_env, env = pcall(function()
		return vim.env.CONSOLE_INLINE_DEBUG or vim.env.CONSOLE_INLINE_DEBUG_NVIM
	end)
	if ok_env and env ~= nil then
		cached = to_boolean(env)
		return cached
	end
	cached = false
	return false
end

local function stringify(value)
	if type(value) == "string" then
		return value
	end
	if vim.inspect then
		return vim.inspect(value)
	end
	return tostring(value)
end

function M.is_debug_enabled()
	return compute_debug_enabled()
end

function M.debug(...)
	if not M.is_debug_enabled() then
		return
	end
	local parts = {}
	for i = 1, select("#", ...) do
		parts[#parts + 1] = stringify(select(i, ...))
	end
	local message = table.concat(parts, " ")
	vim.schedule(function()
		vim.api.nvim_echo({ { "[console-inline] " .. message, "Comment" } }, false, {})
	end)
end

return M
