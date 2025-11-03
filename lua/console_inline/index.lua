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

local state = require("console_inline.state")

local function is_comment(line)
	return line:match("^%s*//") or line:match("^%s*%-%-") or line:match("^%s*/%*")
end

local function tokenize(line)
	local tokens = {}
	for tok in line:gmatch("[%w_]+") do
		if #tok >= 3 and #tok <= 32 then
			-- lower-case normalized
			tokens[#tokens + 1] = tok:lower()
		end
	end
	return tokens
end

local function index_line(buf, line_nr)
	local line = vim.api.nvim_buf_get_lines(buf, line_nr, line_nr + 1, false)[1]
	if not line or line == "" then
		return nil
	end
	local has_console = line:find("console%.") ~= nil
	local has_network = line:find("fetch%s*(%()")
		or line:find("XMLHttpRequest")
		or line:find(":open%s*(%()")
		or line:find(":send%s*(%()")
	local tokens = tokenize(line)
	return {
		console = has_console or false,
		network = has_network or false,
		comment = is_comment(line) and true or false,
		tokens = tokens,
	}
end

local function ensure_buf_index(buf)
	state.buffer_index = state.buffer_index or {}
	local idx = state.buffer_index[buf]
	if not idx then
		idx = { lines = {}, token_map = {} }
		state.buffer_index[buf] = idx
	end
	return idx
end

local function remove_line_tokens(idx, line_nr)
	local prev = idx.lines[line_nr]
	if not prev then
		return
	end
	for _, t in ipairs(prev.tokens or {}) do
		local arr = idx.token_map[t]
		if arr then
			for i = #arr, 1, -1 do
				if arr[i] == line_nr then
					table.remove(arr, i)
				end
			end
			if #arr == 0 then
				idx.token_map[t] = nil
			end
		end
	end
	idx.lines[line_nr] = nil
end

local function store_index(buf, line_nr, data)
	state.buffer_index = state.buffer_index or {}
	local idx = ensure_buf_index(buf)
	remove_line_tokens(idx, line_nr)
	idx.lines[line_nr] = data
	for _, t in ipairs(data.tokens or {}) do
		local arr = idx.token_map[t]
		if not arr then
			arr = {}
			idx.token_map[t] = arr
		end
		-- avoid duplicates
		if arr[#arr] ~= line_nr then
			arr[#arr + 1] = line_nr
		end
	end
end

function M.build(buf)
	if not vim.api.nvim_buf_is_loaded(buf) then
		return
	end
	local idx = ensure_buf_index(buf)
	-- clear existing
	for line_nr in pairs(idx.lines) do
		remove_line_tokens(idx, line_nr)
	end
	local total = vim.api.nvim_buf_line_count(buf)
	for i = 0, total - 1 do
		local data = index_line(buf, i)
		if data then
			store_index(buf, i, data)
		end
	end
end

function M.update_changed(buf, changed_lines)
	if not state.buffer_index or not state.buffer_index[buf] then
		return
	end
	for _, ln in ipairs(changed_lines) do
		local data = index_line(buf, ln)
		if data then
			store_index(buf, ln, data)
		end
	end
end

-- Handle deletion: if line count shrinks, purge orphaned entries beyond new end.
function M.handle_deletions(buf)
	local idx = state.buffer_index and state.buffer_index[buf]
	if not idx then
		return
	end
	local total = vim.api.nvim_buf_line_count(buf)
	for line_nr, _ in pairs(idx.lines) do
		if line_nr >= total then
			remove_line_tokens(idx, line_nr)
		end
	end
end

function M.lookup(buf, tokens, method)
	state.buffer_index = state.buffer_index or {}
	local idx = state.buffer_index[buf]
	if not idx then
		return nil
	end
	local candidate_lines = {}
	local seen = {}
	local function add(line_nr)
		if not seen[line_nr] then
			seen[line_nr] = true
			candidate_lines[#candidate_lines + 1] = line_nr
		end
	end
	-- method literal boost
	local method_literal = method and method:match("^[%w_]+$") and ("console." .. method) or nil
	if method_literal then
		for line_nr, _ in pairs(idx.lines) do
			local line = vim.api.nvim_buf_get_lines(buf, line_nr, line_nr + 1, false)[1]
			if line and line:find(method_literal, 1, true) then
				add(line_nr)
			end
		end
	end
	for _, tok in ipairs(tokens or {}) do
		local arr = idx.token_map[tok:lower()]
		if arr then
			for _, line_nr in ipairs(arr) do
				add(line_nr)
			end
		end
	end
	-- Always include pure console lines if we have few candidates
	if #candidate_lines < 5 then
		for line_nr, meta in pairs(idx.lines) do
			if meta.console then
				add(line_nr)
			end
		end
	end
	return candidate_lines
end

return M
