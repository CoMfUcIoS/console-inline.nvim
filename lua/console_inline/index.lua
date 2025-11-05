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
	local cap = (state.opts and state.opts.max_tokens_per_line) or 120
	for tok in line:gmatch("[%w_]+") do
		if #tokens >= cap then
			break
		end
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
	local skip_len = (state.opts and state.opts.skip_long_lines_len) or 4000
	if #line > skip_len then
		return nil -- skip extremely long/minified lines
	end
	local has_console = line:find("console%.") ~= nil
	local has_network = line:find("fetch%s*(%()")
		or line:find("XMLHttpRequest")
		or line:find(":open%s*(%()")
		or line:find(":send%s*(%()")
	local tokens = tokenize(line)
	local method = nil
	if has_console then
		local m = line:match("console%.([%w_]+)")
		if m then
			method = m
		end
	end
	return {
		console = has_console or false,
		network = has_network or false,
		comment = is_comment(line) and true or false,
		tokens = tokens,
		method = method,
	}
end

local function ensure_buf_index(buf)
	state.buffer_index = state.buffer_index or {}
	local idx = state.buffer_index[buf]
	if not idx then
		idx = { lines = {}, token_map = {}, console_lines = {}, method_map = {}, last_line_count = 0 }
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
	-- remove from console_lines
	if prev.console and idx.console_lines then
		for i = #idx.console_lines, 1, -1 do
			if idx.console_lines[i] == line_nr then
				table.remove(idx.console_lines, i)
			end
		end
	end
	-- remove from method_map
	if prev.method and idx.method_map and idx.method_map[prev.method] then
		local arr = idx.method_map[prev.method]
		for i = #arr, 1, -1 do
			if arr[i] == line_nr then
				table.remove(arr, i)
			end
		end
		if #arr == 0 then
			idx.method_map[prev.method] = nil
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
	if data.console then
		local cl = idx.console_lines
		if cl[#cl] ~= line_nr then
			cl[#cl + 1] = line_nr
		end
	end
	if data.method then
		local mm = idx.method_map[data.method]
		if not mm then
			mm = {}
			idx.method_map[data.method] = mm
		end
		if mm[#mm] ~= line_nr then
			mm[#mm + 1] = line_nr
		end
	end
end

function M.build(buf)
	if not vim.api.nvim_buf_is_loaded(buf) then
		return
	end
	local idx = ensure_buf_index(buf)
	-- clear existing (fast wipe)
	idx.lines = {}
	idx.token_map = {}
	idx.console_lines = idx.console_lines or {}
	idx.method_map = idx.method_map or {}
	for k in pairs(idx.method_map) do
		idx.method_map[k] = nil
	end
	for i = #idx.console_lines, 1, -1 do
		idx.console_lines[i] = nil
	end
	local total = vim.api.nvim_buf_line_count(buf)
	idx.last_line_count = total
	idx.built_until = -1
	idx.building = false
	idx.total_lines = total
	local incremental = (state.opts.incremental_index ~= false) and total > (state.opts.index_batch_size * 4)
	if not incremental then
		for i = 0, total - 1 do
			local data = index_line(buf, i)
			if data then
				store_index(buf, i, data)
			end
		end
		idx.built_until = total - 1
		return
	end
	-- incremental build scheduling
	local batch = math.max(200, state.opts.index_batch_size or 1000)
	idx.building = true
	local function step()
		if not vim.api.nvim_buf_is_loaded(buf) then
			idx.building = false
			return
		end
		local start = idx.built_until + 1
		if start >= total then
			idx.building = false
			return
		end
		local finish = math.min(total - 1, start + batch - 1)
		for ln = start, finish do
			local data = index_line(buf, ln)
			if data then
				store_index(buf, ln, data)
			end
		end
		idx.built_until = finish
		if finish < total - 1 then
			vim.defer_fn(step, 10) -- small delay to yield UI
		else
			idx.building = false
		end
	end
	step()
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
	if total >= idx.last_line_count then
		idx.last_line_count = total
		return -- no shrink, nothing to purge
	end
	for line_nr = total, idx.last_line_count - 1 do
		if idx.lines[line_nr] then
			remove_line_tokens(idx, line_nr)
		end
	end
	state.deletion_stats.sweeps = (state.deletion_stats.sweeps or 0) + 1
	idx.last_line_count = total
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
	-- method literal boost via precomputed method_map
	if method and idx.method_map[method] then
		for _, line_nr in ipairs(idx.method_map[method]) do
			add(line_nr)
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
	-- Always include pure console lines if we have few candidates (use console_lines array)
	if #candidate_lines < 5 and idx.console_lines then
		for _, line_nr in ipairs(idx.console_lines) do
			add(line_nr)
		end
	end
	return candidate_lines
end

function M.reindex(buf)
	if not vim.api.nvim_buf_is_loaded(buf) then
		return
	end
	-- Clear the existing index for this buffer
	if state.buffer_index and state.buffer_index[buf] then
		state.buffer_index[buf] = nil
	end
	-- Rebuild from scratch
	M.build(buf)
end

return M
