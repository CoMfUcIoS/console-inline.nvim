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

-- Global history storage (backward compatible)
local function ensure_history()
	state.history = state.history or {}
	return state.history
end

-- Per-line history storage: history_by_buf_line[bufnr][lnum] = { entries = [...], current_index = 1 }
local function ensure_per_line_history()
	state.history_by_buf_line = state.history_by_buf_line or {}
	return state.history_by_buf_line
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

-- Record a message for a specific buffer/line in per-line history
function M.record_per_line(bufnr, lnum, entry)
	if type(entry) ~= "table" or not bufnr or not lnum then
		return
	end
	local by_line = ensure_per_line_history()
	by_line[bufnr] = by_line[bufnr] or {}
	local line_entries = by_line[bufnr][lnum]
	
	if not line_entries then
		line_entries = { entries = {}, current_index = 1 }
		by_line[bufnr][lnum] = line_entries
	end
	
	-- Add new entry and set current index to first (oldest shown first)
	table.insert(line_entries.entries, entry)
	line_entries.current_index = 1
end

-- Get current entry for a buffer line
function M.get_current_per_line(bufnr, lnum)
	local by_line = ensure_per_line_history()
	if not by_line[bufnr] or not by_line[bufnr][lnum] then
		return nil
	end
	local line_entries = by_line[bufnr][lnum]
	return line_entries.entries[line_entries.current_index]
end

-- Move to next entry on a specific buffer line
function M.next_per_line(bufnr, lnum)
	local by_line = ensure_per_line_history()
	if not by_line[bufnr] or not by_line[bufnr][lnum] then
		return nil
	end
	local line_entries = by_line[bufnr][lnum]
	local count = #line_entries.entries
	if count == 0 then
		return nil
	end
	
	line_entries.current_index = line_entries.current_index + 1
	if line_entries.current_index > count then
		line_entries.current_index = 1
	end
	return line_entries.entries[line_entries.current_index]
end

-- Move to previous entry on a specific buffer line
function M.prev_per_line(bufnr, lnum)
	local by_line = ensure_per_line_history()
	if not by_line[bufnr] or not by_line[bufnr][lnum] then
		return nil
	end
	local line_entries = by_line[bufnr][lnum]
	local count = #line_entries.entries
	if count == 0 then
		return nil
	end
	
	line_entries.current_index = line_entries.current_index - 1
	if line_entries.current_index < 1 then
		line_entries.current_index = count
	end
	return line_entries.entries[line_entries.current_index]
end

-- Get total count and current index for display
function M.get_position_per_line(bufnr, lnum)
	local by_line = ensure_per_line_history()
	if not by_line[bufnr] or not by_line[bufnr][lnum] then
		return nil, nil
	end
	local line_entries = by_line[bufnr][lnum]
	return line_entries.current_index, #line_entries.entries
end

-- Clear per-line history for a buffer
function M.clear_per_line_buffer(bufnr)
	local by_line = ensure_per_line_history()
	by_line[bufnr] = nil
end

function M.entries()
	return ensure_history()
end

function M.clear()
	state.history = {}
	state.history_by_buf_line = {}
end

function M.is_empty()
	return #ensure_history() == 0
end

return M
