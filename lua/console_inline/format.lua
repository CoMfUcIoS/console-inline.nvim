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
		for idx, value in ipairs(args) do
			local formatted = format_value(value)
			append_tagged(lines, string.format("[%d] ", idx), formatted)
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

return M
