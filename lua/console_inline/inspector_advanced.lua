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

--[[
Advanced inspector features for console-inline.nvim

Provides:
- Object diffing (compare two logged objects)
- JSON export to file
- Timeline view with time-based filtering
- Performance metrics per file (message rate, payload size)
- Custom value formatters registry
]]

local state = require("console_inline.state")

local M = {}

-- Custom formatter registry: data_type -> formatter_function
M.custom_formatters = {}

-- Register custom formatter for a specific data type
function M.register_formatter(data_type, formatter_fn)
	assert(type(data_type) == "string", "data_type must be string")
	assert(type(formatter_fn) == "function", "formatter_fn must be function")
	M.custom_formatters[data_type] = formatter_fn
end

-- Get custom formatter for data type
local function get_formatter(data_type)
	return M.custom_formatters[data_type]
end

-- Format value using custom formatter or default JSON
local function format_value(value, data_type)
	local formatter = get_formatter(data_type)
	if formatter then
		return formatter(value)
	end
	return vim.json.encode(value)
end

--[[
Object Diffing

Compare two objects and show additions/deletions/modifications.
]]

function M.diff_objects(obj1, obj2)
	local diff = {
		added = {},
		removed = {},
		modified = {},
		unchanged = {},
	}

	-- Find removed and modified keys
	for key, val1 in pairs(obj1) do
		if obj2[key] == nil then
			diff.removed[key] = val1
		elseif obj2[key] ~= val1 then
			diff.modified[key] = { old = val1, new = obj2[key] }
		else
			diff.unchanged[key] = val1
		end
	end

	-- Find added keys
	for key, val2 in pairs(obj2) do
		if obj1[key] == nil then
			diff.added[key] = val2
		end
	end

	return diff
end

-- Format diff for display
function M.format_diff(diff)
	local lines = {}

	table.insert(lines, "")
	table.insert(lines, "━━━━━ OBJECT DIFF ━━━━━")
	table.insert(lines, "")

	if vim.tbl_count(diff.added) > 0 then
		table.insert(lines, "✚ ADDED:")
		for key, val in pairs(diff.added) do
			table.insert(lines, string.format("  + %s = %s", key, format_value(val, type(val))))
		end
		table.insert(lines, "")
	end

	if vim.tbl_count(diff.removed) > 0 then
		table.insert(lines, "✖ REMOVED:")
		for key, val in pairs(diff.removed) do
			table.insert(lines, string.format("  - %s = %s", key, format_value(val, type(val))))
		end
		table.insert(lines, "")
	end

	if vim.tbl_count(diff.modified) > 0 then
		table.insert(lines, "✏ MODIFIED:")
		for key, change in pairs(diff.modified) do
			table.insert(lines, string.format("  ~ %s", key))
			table.insert(lines, string.format("    old: %s", format_value(change.old, type(change.old))))
			table.insert(lines, string.format("    new: %s", format_value(change.new, type(change.new))))
		end
		table.insert(lines, "")
	end

	if vim.tbl_count(diff.unchanged) > 0 then
		table.insert(lines, string.format("= UNCHANGED (%d keys)", vim.tbl_count(diff.unchanged)))
	end

	return table.concat(lines, "\n")
end

--[[
JSON Export

Export messages to JSON file for external analysis
]]

function M.export_to_json(filename, entries)
	entries = entries or state.history
	local ok, encoded = pcall(vim.json.encode, entries)
	if not ok then
		return false, "Failed to encode entries: " .. tostring(encoded)
	end

	local file, err = io.open(filename, "w")
	if not file then
		return false, "Failed to open file: " .. err
	end

	file:write(encoded)
	file:close()

	return true, string.format("Exported %d entries to %s", #entries, filename)
end

--[[
Timeline View

Filter and display messages in chronological order with time-based filtering
]]

function M.get_timeline(entries, time_range_seconds)
	time_range_seconds = time_range_seconds or nil
	local now = vim.fn.localtime()

	local filtered = {}
	for _, entry in ipairs(entries or state.history) do
		if not time_range_seconds then
			table.insert(filtered, entry)
		else
			local entry_time = entry.timestamp or entry.time or 0
			local age = now - entry_time
			if age >= 0 and age <= time_range_seconds then
				table.insert(filtered, entry)
			end
		end
	end

	-- Sort by timestamp
	table.sort(filtered, function(a, b)
		local time_a = a.timestamp or a.time or 0
		local time_b = b.timestamp or b.time or 0
		return time_a < time_b
	end)

	return filtered
end

-- Format timeline for display
function M.format_timeline(entries)
	local lines = { "━━━━━ TIMELINE ━━━━━" }

	for i, entry in ipairs(entries) do
		local time = entry.timestamp or entry.time or 0
		local time_str = os.date("%H:%M:%S", time)
		local kind = entry.kind or "log"
		local file = entry.file or "<unknown>"
		local short_file = vim.fn.fnamemodify(file, ":~:.")
		local msg = entry.payload or entry.display or ""

		table.insert(lines, string.format("[%s] <%s> %s:%d", time_str, kind, short_file, entry.line or 0))
		table.insert(lines, string.format("  %s", msg:sub(1, 60)))
		table.insert(lines, "")
	end

	return table.concat(lines, "\n")
end

--[[
Performance Metrics

Track message rate and payload sizes per file
]]

function M.get_metrics(entries)
	entries = entries or state.history
	local metrics = {
		total_messages = #entries,
		by_file = {},
		by_severity = {},
		avg_payload_size = 0,
		max_payload_size = 0,
	}

	local total_size = 0

	for _, entry in ipairs(entries) do
		local file = entry.file or "<unknown>"
		local kind = entry.kind or "log"
		local payload = entry.payload or entry.display or ""
		local payload_size = #payload

		-- File metrics
		if not metrics.by_file[file] then
			metrics.by_file[file] = {
				count = 0,
				total_size = 0,
				avg_size = 0,
				severities = {},
			}
		end

		metrics.by_file[file].count = metrics.by_file[file].count + 1
		metrics.by_file[file].total_size = metrics.by_file[file].total_size + payload_size

		-- Severity metrics
		if not metrics.by_severity[kind] then
			metrics.by_severity[kind] = 0
		end
		metrics.by_severity[kind] = metrics.by_severity[kind] + 1

		total_size = total_size + payload_size
		metrics.max_payload_size = math.max(metrics.max_payload_size, payload_size)
	end

	-- Calculate averages
	if metrics.total_messages > 0 then
		metrics.avg_payload_size = total_size / metrics.total_messages
	end

	for file, file_metrics in pairs(metrics.by_file) do
		if file_metrics.count > 0 then
			file_metrics.avg_size = file_metrics.total_size / file_metrics.count
		end
	end

	return metrics
end

-- Format metrics for display
function M.format_metrics(metrics)
	local lines = { "━━━━━ PERFORMANCE METRICS ━━━━━" }

	table.insert(lines, "")
	table.insert(lines, string.format("Total Messages: %d", metrics.total_messages))
	table.insert(lines, string.format("Avg Payload Size: %d bytes", math.floor(metrics.avg_payload_size)))
	table.insert(lines, string.format("Max Payload Size: %d bytes", metrics.max_payload_size))
	table.insert(lines, "")

	table.insert(lines, "By Severity:")
	for kind, count in pairs(metrics.by_severity) do
		table.insert(lines, string.format("  %s: %d", kind, count))
	end
	table.insert(lines, "")

	table.insert(lines, "Top Files (by message count):")
	local file_list = {}
	for file, file_metrics in pairs(metrics.by_file) do
		table.insert(file_list, { file = file, count = file_metrics.count, size = file_metrics.avg_size })
	end
	table.sort(file_list, function(a, b)
		return a.count > b.count
	end)

	for i, item in ipairs(file_list) do
		if i > 10 then
			break
		end
		local short_file = vim.fn.fnamemodify(item.file, ":~")
		table.insert(lines, string.format("  %s: %d msgs (avg %d bytes)", short_file, item.count, math.floor(item.size)))
	end

	return table.concat(lines, "\n")
end

--[[
Open Inspector with Advanced Features Panel
]]

function M.open_advanced()
	-- Find existing buffer or create new one
	local buf = nil
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(b) then
			local name = vim.api.nvim_buf_get_name(b)
			if name:find("ConsoleInlineAdvanced", 1, true) then
				buf = b
				break
			end
		end
	end

	if not buf then
		buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(buf, "ConsoleInlineAdvanced")
	end
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })

	local lines = {
		"┌─ Console Inline Advanced Inspector ────────────────┐",
		"│ <1> Metrics  <2> Timeline  <3> Export  <q> Close  │",
		"├────────────────────────────────────────────────────┤",
	}

	local metrics = M.get_metrics()
	local metrics_display = M.format_metrics(metrics)
	for line in metrics_display:gmatch("[^\n]+") do
		table.insert(lines, "│ " .. line)
	end

	table.insert(lines, "└────────────────────────────────────────────────────┘")

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = 80,
		height = 30,
		row = 2,
		col = 10,
		border = "rounded",
		title = " Advanced Inspector ",
	})

	local opts = { noremap = true, silent = true, buffer = buf }

	vim.keymap.set("n", "1", function()
		-- Show metrics
		vim.notify("Metrics: " .. vim.json.encode(metrics), vim.log.levels.INFO)
	end, opts)

	vim.keymap.set("n", "2", function()
		-- Show timeline
		local timeline_entries = M.get_timeline(nil, 3600) -- Last hour
		vim.notify("Timeline: " .. #timeline_entries .. " entries", vim.log.levels.INFO)
	end, opts)

	vim.keymap.set("n", "3", function()
		-- Export to file
		local filename = vim.fn.expand("~") .. "/console_inline_export.json"
		local ok, msg = M.export_to_json(filename)
		vim.notify(msg, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
	end, opts)

	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, opts)

	vim.keymap.set("n", "<Esc>", function()
		vim.api.nvim_win_close(win, true)
	end, opts)
end

return M
