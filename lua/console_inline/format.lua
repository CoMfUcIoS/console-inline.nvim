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
local unpack = _G.unpack --luacheck: ignore

-- Detect the type of a value and return its highlight group
local function get_type_highlight(value)
	local t = type(value)
	if t == "string" then
		return "ConsoleInlineString"
	elseif t == "number" then
		return "ConsoleInlineNumber"
	elseif t == "boolean" then
		return "ConsoleInlineBoolean"
	elseif t == "nil" then
		return "ConsoleInlineNull"
	elseif t == "table" then
		if vim.tbl_islist(value) then
			return "ConsoleInlineArray"
		else
			return "ConsoleInlineObject"
		end
	elseif t == "function" then
		return "ConsoleInlineFunction"
	else
		return "ConsoleInlineSymbol"
	end
end

-- Try to detect special types (Date, Regex) from their string representation
local function detect_special_type(value_str)
	if type(value_str) ~= "string" then
		return nil
	end
	-- ISO 8601 date format
	if value_str:match("^%d%d%d%d%-%-?%d%d%-%-?%d%dT") then
		return "ConsoleInlineDate"
	end
	-- Regex pattern
	if value_str:match("^/.*/$") then
		return "ConsoleInlineRegex"
	end
	return nil
end

local function try_json(value)
	if type(value) ~= "string" then
		return nil
	end
	local trimmed = value:match("^%s*(.-)%s*$") or value
	if not trimmed:match("^%s*[%[{]") then
		return nil
	end
	local ok, decoded = pcall(vim.json.decode, value)
	if not ok then
		return nil
	end
	local ok_inspect, formatted = pcall(vim.inspect, decoded)
	if ok_inspect then
		return formatted
	end
	return nil
end

-- Format a value with type information (for type-aware highlighting)
local function format_value_with_type(value)
	local t = type(value)
	if t == "string" then
		local json_fmt = try_json(value)
		if json_fmt then
			return json_fmt, nil
		end
		return value, get_type_highlight(value)
	end
	if t == "number" or t == "boolean" then
		return vim.inspect(value), get_type_highlight(value)
	end
	if t == "nil" then
		return "nil", "ConsoleInlineNull"
	end
	local ok, formatted = pcall(vim.inspect, value)
	if ok then
		local special = detect_special_type(formatted)
		if special then
			return formatted, special
		end
		return formatted, get_type_highlight(value)
	end
	return tostring(value), nil
end

local function format_value(value)
	local t = type(value)
	if t == "string" then
		local json_fmt = try_json(value)
		if json_fmt then
			return json_fmt
		end
		return value
	end
	if t == "number" or t == "boolean" or t == "nil" then
		return vim.inspect(value)
	end
	local ok, formatted = pcall(vim.inspect, value)
	if ok then
		return formatted
	end
	return tostring(value)
end

local function append_tagged(lines, tag, text)
	text = text:gsub("\r", "")
	local pieces = vim.split(text, "\n", true)
	if #pieces == 0 then
		table.insert(lines, tag)
		return
	end
	pieces[1] = tag .. pieces[1]
	local pad = string.rep(" ", #tag)
	for i = 2, #pieces do
		pieces[i] = pad .. pieces[i]
	end
	vim.list_extend(lines, pieces)
end

-- Detect and apply printf-style formatting (e.g., "%s: %s" with args)
-- Returns the formatted string or nil if not a format string
local function try_apply_format(fmt_string, args)
	if type(fmt_string) ~= "string" then
		return nil
	end
	if not fmt_string:find("%%") then
		return nil
	end
	if not args or #args == 0 then
		return nil
	end
	local ok, result = pcall(function()
		-- Prepare arguments for string.format
		-- Convert non-string values to their string representation
		local format_args = {}
		for i, arg in ipairs(args) do
			if type(arg) == "string" then
				format_args[i] = arg
			elseif arg == nil then
				format_args[i] = "nil"
			else
				format_args[i] = tostring(arg)
			end
		end
		return string.format(fmt_string, unpack(format_args))
	end)
	if ok and result then
		return result
	end
	return nil
end

function M.default(entry)
	if not entry then
		return { "<no entry>" }
	end
	local lines = {}
	-- Optional dual coordinate display
	local state_ok, state = pcall(require, "console_inline.state")
	if state_ok and state.opts.show_original_and_transformed then
		local of = entry.original_file or entry.file
		local ol = entry.original_line or entry.render_line or entry.line
		local tf = entry.transformed_file or of
		local tl = entry.transformed_line or ol
		local oc = entry.original_column
		local tc = entry.transformed_column or oc
		local differ = (of ~= tf) or (ol ~= tl) or (oc and tc and oc ~= tc)
		if differ then
			local orig_coord =
				string.format("%s:%s%s", of or "<unknown>", tostring(ol or "?"), oc and (":" .. tostring(oc)) or "")
			local trans_coord =
				string.format("%s:%s%s", tf or "<unknown>", tostring(tl or "?"), tc and (":" .. tostring(tc)) or "")
			append_tagged(lines, "[orig] ", orig_coord)
			append_tagged(lines, "[built] ", trans_coord)
		end
	end
	local args = entry.raw_args or {}
	if #args == 0 then
		local payload = entry.payload or entry.text or ""
		append_tagged(lines, "", format_value(payload))
	else
		-- Check if this looks like a printf-style format string
		-- (first arg is a string with % placeholders, followed by values)
		local first_arg = args[1]
		if type(first_arg) == "string" and first_arg:find("%%") and #args > 1 then
			-- Try to apply printf-style formatting
			local formatted = try_apply_format(first_arg, { unpack(args, 2) })
			if formatted then
				append_tagged(lines, "", format_value(formatted))
			else
				-- Format string parsing failed, show all args individually
				for idx, value in ipairs(args) do
					local formatted_val = format_value(value)
					append_tagged(lines, string.format("[%d] ", idx), formatted_val)
				end
			end
		else
			-- Regular arguments (not printf-style)
			for idx, value in ipairs(args) do
				local formatted = format_value(value)
				append_tagged(lines, string.format("[%d] ", idx), formatted)
			end
		end
	end
	local trace = entry.trace or {}
	if type(trace) == "table" and #trace > 0 then
		for idx, frame in ipairs(trace) do
			append_tagged(lines, string.format("[trace %d] ", idx), tostring(frame))
		end
	end
	local timer = entry.time
	if type(timer) == "table" and timer.label then
		local label = timer.label or "timer"
		local line
		if timer.duration_ms then
			line = string.format("%s: %.3f ms", label, tonumber(timer.duration_ms) or 0)
		elseif timer.missing then
			line = string.format("Timer '%s' not found", label)
		else
			line = label
		end
		append_tagged(lines, "[time] ", line)
	end
	if #lines == 0 then
		lines = { entry.text or "" }
	end
	return lines
end

-- Format with type information for inline virtual text highlighting
-- Returns array of { text = string, hl = string } tables
function M.inline_typed(entry)
	if not entry then
		return { { text = "", hl = nil } }
	end

	local state_ok, state = pcall(require, "console_inline.state")
	if not state_ok or state.opts.type_highlighting == false then
		-- Fallback to single-color output
		return { { text = entry.text or "", hl = entry.highlight or "NonText" } }
	end

	local args = entry.raw_args or {}
	local segments = {}

	if #args == 0 then
		local payload = entry.payload or entry.text or ""
		local fmt, hl = format_value_with_type(payload)
		segments[#segments + 1] = { text = fmt, hl = hl }
	else
		-- Check if this looks like a printf-style format string
		-- (first arg is a string with % placeholders, followed by values)
		local first_arg = args[1]
		if type(first_arg) == "string" and first_arg:find("%%") and #args > 1 then
			-- Try to apply printf-style formatting
			local formatted = try_apply_format(first_arg, { unpack(args, 2) })
			if formatted then
				local fmt_hl, hl = format_value_with_type(formatted)
				segments[#segments + 1] = { text = fmt_hl, hl = hl }
			else
				-- Format string parsing failed, fall back to showing all args
				for idx, value in ipairs(args) do
					if idx > 1 then
						segments[#segments + 1] = { text = " ", hl = nil }
					end
					local formatted_val, hl_val = format_value_with_type(value)
					segments[#segments + 1] = { text = formatted_val, hl = hl_val }
				end
			end
		else
			-- Regular arguments (not printf-style)
			for idx, value in ipairs(args) do
				-- Add space separator between arguments
				if idx > 1 then
					segments[#segments + 1] = { text = " ", hl = nil }
				end
				local formatted, hl = format_value_with_type(value)
				segments[#segments + 1] = { text = formatted, hl = hl }
			end
		end
	end

	return #segments > 0 and segments or { { text = entry.text or "", hl = nil } }
end

return M
