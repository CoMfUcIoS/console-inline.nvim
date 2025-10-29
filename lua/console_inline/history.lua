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
