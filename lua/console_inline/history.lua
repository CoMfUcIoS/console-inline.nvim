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

local state = require("console_inline.state")

local M = {}

local function ensure_history()
	state.history = state.history or {}
	return state.history
end

local function trim_history()
	local max = tonumber(state.opts.history_size) or 0
	if max <= 0 then
		return
	end
	local history = ensure_history()
	while #history > max do
		table.remove(history)
	end
end

function M.record(entry)
	if type(entry) ~= "table" then
		return
	end
	local history = ensure_history()
	table.insert(history, 1, entry)
	trim_history()
end

function M.entries()
	return ensure_history()
end

function M.clear()
	state.history = {}
end

function M.is_empty()
	return #ensure_history() == 0
end

return M
