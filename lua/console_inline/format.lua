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
	if #lines == 0 then
		lines = { entry.text or "" }
	end
	return lines
end

return M
