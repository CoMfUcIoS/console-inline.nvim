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
local history = require("console_inline.history")

local M = {}

-- Store metadata for entries
local inspector_state = {
	entries_by_line = {}, -- Maps display line number to entry object
	current_grouping = "severity", -- 'severity', 'file', or 'none'
}

-- Create inspector buffer with all messages
function M.open()
	-- Get all messages from history
	local entries = history.entries()
	if not entries or #entries == 0 then
		vim.notify("console-inline: no messages in history", vim.log.levels.WARN)
		return
	end
	
	-- Create a new buffer
	local buf = vim.api.nvim_create_buf(true, true)
	if buf == 0 then
		vim.notify("console-inline: failed to create buffer", vim.log.levels.ERROR)
		return
	end
	
	-- Build display lines and store entry metadata
	inspector_state.entries_by_line = {}
	local lines = { "╔════════════════════════ Console Inspector ════════════════════════╗" }
	lines[#lines + 1] = "║ Bindings: <CR>=jump, y=yank, c=clear, /=search, g=group, q=quit   ║"
	lines[#lines + 1] = "╚═══════════════════════════════════════════════════════════════════╝"
	lines[#lines + 1] = ""
	
	-- Render entries based on current grouping
	if inspector_state.current_grouping == "severity" then
		render_by_severity(lines, entries)
	elseif inspector_state.current_grouping == "file" then
		render_by_file(lines, entries)
	else
		render_flat(lines, entries)
	end
	
	-- Set buffer content
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	
	-- Create floating window or split
	local inspector_opts = state.opts.inspector or {}
	local use_float = inspector_opts.floating ~= false
	
	local win
	if use_float then
		local width = inspector_opts.width or 80
		local height = inspector_opts.height or 30
		local row = inspector_opts.row or math.floor((vim.o.lines - height) / 2)
		local col = inspector_opts.col or math.floor((vim.o.columns - width) / 2)
		
		win = vim.api.nvim_open_win(buf, true, {
			relative = "editor",
			width = width,
			height = height,
			row = row,
			col = col,
			style = "minimal",
			border = "rounded",
			title = " Console Inspector ",
		})
		
		if win == 0 then
			vim.notify("console-inline: failed to create window", vim.log.levels.ERROR)
			return
		end
		
		vim.api.nvim_set_current_win(win)
	else
		-- Use split layout
		vim.cmd("split")
		vim.api.nvim_set_current_buf(buf)
		win = vim.api.nvim_get_current_win()
	end
	
	-- Setup keymaps
	setup_keys(buf, win, use_float)
	vim.notify("Inspector opened. Use q or Esc to close.", vim.log.levels.INFO)
end

-- Render entries grouped by severity
function render_by_severity(lines, entries)
	local severity_order = { "error", "warn", "info", "log" }
	local entries_by_severity = {}
	
	for _, severity in ipairs(severity_order) do
		entries_by_severity[severity] = {}
	end
	
	for _, entry in ipairs(entries) do
		local severity = entry.kind or "log"
		if not entries_by_severity[severity] then
			entries_by_severity[severity] = {}
		end
		entries_by_severity[severity][#entries_by_severity[severity] + 1] = entry
	end
	
	local severity_icons = {
		error = "✖",
		warn = "⚠",
		info = "ℹ",
		log = "●",
	}
	
	for _, severity in ipairs(severity_order) do
		local group_entries = entries_by_severity[severity]
		if #group_entries > 0 then
			local icon = severity_icons[severity] or "●"
			lines[#lines + 1] = string.format("  %s %s (%d messages)", icon, severity:upper(), #group_entries)
			lines[#lines + 1] = "  " .. string.rep("─", 62)
			
			for _, entry in ipairs(group_entries) do
				add_entry_line(lines, entry)
			end
			lines[#lines + 1] = ""
		end
	end
end

-- Render entries grouped by file
function render_by_file(lines, entries)
	local entries_by_file = {}
	
	for _, entry in ipairs(entries) do
		local file = entry.file or "<unknown>"
		if not entries_by_file[file] then
			entries_by_file[file] = {}
		end
		entries_by_file[file][#entries_by_file[file] + 1] = entry
	end
	
	-- Sort files for consistent display
	local files = {}
	for file, _ in pairs(entries_by_file) do
		files[#files + 1] = file
	end
	table.sort(files)
	
	for _, file in ipairs(files) do
		local group_entries = entries_by_file[file]
		local short_file = vim.fn.fnamemodify(file, ":~:.")
		lines[#lines + 1] = string.format("  📄 %s (%d messages)", short_file, #group_entries)
		lines[#lines + 1] = "  " .. string.rep("─", 62)
		
		for _, entry in ipairs(group_entries) do
			add_entry_line(lines, entry)
		end
		lines[#lines + 1] = ""
	end
end

-- Render entries flat (no grouping)
function render_flat(lines, entries)
	for _, entry in ipairs(entries) do
		add_entry_line(lines, entry)
	end
end

-- Add a single entry line and store metadata
function add_entry_line(lines, entry)
	local file = entry.file or "<unknown>"
	local short_file = vim.fn.fnamemodify(file, ":~:.")
	local line_no = entry.render_line or entry.original_line or entry.line or 0
	
	-- Truncate long messages
	local payload = entry.payload or entry.display or entry.text or ""
	local max_len = 50
	if #payload > max_len then
		payload = payload:sub(1, max_len - 1) .. "…"
	end
	
	-- Store full path and line for later retrieval
	local display_line = string.format("    %s:%d %s", short_file, line_no, payload)
	local line_idx = #lines + 1
	lines[line_idx] = display_line
	
	-- Store entry metadata indexed by line number
	inspector_state.entries_by_line[line_idx] = {
		entry = entry,
		file = file,
		line = line_no,
		short_file = short_file,
	}
end

-- Setup keymaps for the inspector
function setup_keys(buf, win, use_float)
	local function close_inspector()
		if use_float then
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		else
			vim.cmd("close")
		end
	end
	
	-- Jump to source
	vim.keymap.set("n", "<CR>", function()
		local line_idx = vim.api.nvim_win_get_cursor(0)[1]
		local entry_data = inspector_state.entries_by_line[line_idx]
		
		if entry_data and entry_data.file then
			local file = entry_data.file
			-- Expand tilde and relative paths
			file = vim.fn.expand(file)
			
			-- Close inspector before opening file
			close_inspector()
			
			-- Open file and jump to line
			local ok, err = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(file))
			if ok then
				vim.api.nvim_win_set_cursor(0, { entry_data.line, 0 })
			else
				vim.notify(
					string.format("console-inline: failed to open %s (%s)", file, err),
					vim.log.levels.ERROR
				)
			end
		end
	end, { buffer = buf, silent = true })
	
	-- Yank entry (formatted)
	vim.keymap.set("n", "y", function()
		local line_idx = vim.api.nvim_win_get_cursor(0)[1]
		local entry_data = inspector_state.entries_by_line[line_idx]
		
		if entry_data and entry_data.entry then
			local entry = entry_data.entry
			-- Format the entry nicely
			local lines_formatted = {}
			
			if entry.file then
				lines_formatted[#lines_formatted + 1] = "File: " .. entry.file
			end
			if entry.render_line or entry.line then
				lines_formatted[#lines_formatted + 1] =
					"Line: " .. tostring(entry.render_line or entry.line)
			end
			if entry.kind then
				lines_formatted[#lines_formatted + 1] = "Kind: " .. entry.kind
			end
			if entry.payload then
				lines_formatted[#lines_formatted + 1] = "Content: " .. entry.payload
			end
			
			local text = table.concat(lines_formatted, "\n")
			vim.fn.setreg("+", text)
			vim.notify("Copied entry to clipboard", vim.log.levels.INFO)
		else
			local line = vim.api.nvim_get_current_line()
			vim.fn.setreg("+", line)
			vim.notify("Copied line to clipboard", vim.log.levels.INFO)
		end
	end, { buffer = buf, silent = true })
	
	-- Clear history
	vim.keymap.set("n", "c", function()
		local confirm = vim.fn.confirm("Clear all history?", "&Yes\n&No")
		if confirm == 1 then
			history.clear()
			inspector_state.entries_by_line = {}
			vim.notify("History cleared", vim.log.levels.INFO)
			close_inspector()
		end
	end, { buffer = buf, silent = true })
	
	-- Search (use Neovim's built-in search)
	vim.keymap.set("n", "/", function()
		vim.cmd("normal /")
	end, { buffer = buf, silent = true })
	
	-- Toggle grouping
	vim.keymap.set("n", "g", function()
		-- Cycle through grouping options
		local groupings = { "severity", "file", "none" }
		local current_idx = 1
		for i, g in ipairs(groupings) do
			if g == inspector_state.current_grouping then
				current_idx = i
				break
			end
		end
		local next_idx = (current_idx % #groupings) + 1
		inspector_state.current_grouping = groupings[next_idx]
		
		vim.notify(
			"Inspector grouping: " .. inspector_state.current_grouping,
			vim.log.levels.INFO
		)
		
		-- Reload inspector with new grouping
		close_inspector()
		M.open()
	end, { buffer = buf, silent = true })
	
	-- Close/quit
	vim.keymap.set("n", "q", close_inspector, { buffer = buf, silent = true })
	vim.keymap.set("n", "<Esc>", close_inspector, { buffer = buf, silent = true })
end

return M
