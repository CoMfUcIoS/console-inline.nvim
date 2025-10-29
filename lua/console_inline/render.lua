local state = require("console_inline.state")
local compat = require("console_inline.compat")
local log = require("console_inline.log")
local history = require("console_inline.history")
local filters = require("console_inline.filters")

local M = {}

local default_pattern_overrides = {
	{ pattern = "TODO", icon = "📝", highlight = "Todo", plain = true, ignore_case = true },
	{ pattern = "FIXME", icon = "🛠", highlight = "WarningMsg", plain = true, ignore_case = true },
	{ pattern = "NOTE", icon = "🗒", highlight = "SpecialComment", plain = true, ignore_case = true },
}

local function is_remote_path(path)
	if type(path) ~= "string" then
		return false
	end
	return path:match("^%a[%w%+%-%.]*://") ~= nil
end

local function stringify_args(args)
	local ok, s = pcall(vim.json.encode, args)
	if not ok or type(s) ~= "string" then
		s = vim.inspect(args)
	end
	-- remove control characters and collapse whitespace
	s = s:gsub("[%c]", " "):gsub("%s+", " ")
	return s
end

local function truncate(str, max)
	if #str <= max then
		return str
	end
	return str:sub(1, math.max(0, max - 1)) .. "…"
end

local right_align = nil
local function virt_pos()
	if right_align == nil then
		right_align = compat.supports_right_align()
	end
	return right_align and "eol_right_align" or "eol"
end

local function severity_icon(kind)
	if kind == "error" then
		return "✖", "DiagnosticError"
	end
	if kind == "warn" then
		return "⚠", "DiagnosticWarn"
	end
	return "●", (kind == "info" and "DiagnosticInfo" or "NonText")
end

local function matches_pattern(text, rule)
	local pattern = rule.pattern
	if type(pattern) ~= "string" or pattern == "" then
		return false
	end
	text = tostring(text or "")
	if rule.plain then
		if rule.ignore_case then
			return text:lower():find(pattern:lower(), 1, true) ~= nil
		end
		return text:find(pattern, 1, true) ~= nil
	end
	if rule.ignore_case then
		text = text:lower()
		pattern = pattern:lower()
	end
	local ok, start_pos = pcall(string.find, text, pattern)
	if not ok then
		log.debug("pattern override error", pattern)
		return false
	end
	return start_pos ~= nil
end

local function apply_rules(payload, icon, hl, rules)
	if type(rules) ~= "table" then
		return false, icon, hl
	end
	for _, rule in ipairs(rules) do
		if type(rule) == "table" and matches_pattern(payload, rule) then
			local new_icon = rule.icon or icon
			local new_hl = rule.highlight or hl
			return true, new_icon, new_hl
		end
	end
	return false, icon, hl
end

local function apply_pattern_overrides(payload, icon, hl)
	local overrides = state.opts.pattern_overrides
	if overrides == false then
		return icon, hl
	end
	local matched_override, override_icon, override_hl = apply_rules(payload, icon, hl, overrides)
	if matched_override then
		return override_icon, override_hl
	end
	local matched_default, default_icon, default_hl = apply_rules(payload, icon, hl, default_pattern_overrides)
	if matched_default then
		return default_icon, default_hl
	end
	return icon, hl
end

local function clamp_line(buf, line0)
	if type(line0) ~= "number" then
		return 0
	end
	line0 = math.max(0, math.floor(line0))
	local count = vim.api.nvim_buf_line_count(buf)
	if count <= 0 then
		return 0
	end
	if line0 >= count then
		return count - 1
	end
	return line0
end

local function has_console(buf, line0)
	local line = vim.api.nvim_buf_get_lines(buf, line0, line0 + 1, false)[1]
	if not line then
		return false
	end
	return line:match("console%.") ~= nil
end

local function adjust_line(buf, line0)
	if has_console(buf, line0) then
		return line0
	end
	local max = vim.api.nvim_buf_line_count(buf)
	for offset = 1, 6 do
		local down = line0 + offset
		if down < max and has_console(buf, down) then
			return down
		end
	end
	for offset = 1, 3 do
		local up = line0 - offset
		if up >= 0 and has_console(buf, up) then
			return up
		end
	end
	return line0
end

local function set_line_text(buf, line0, entry, hl)
	local text = entry.text
	state.extmarks_by_buf_line[buf] = state.extmarks_by_buf_line[buf] or {}
	state.last_msg_by_buf_line[buf] = state.last_msg_by_buf_line[buf] or {}
	local id = state.extmarks_by_buf_line[buf][line0]
	local opts = {
		virt_text = { { text, hl } },
		virt_text_pos = virt_pos(),
		hl_mode = "combine",
		priority = 200,
	}
	if id then
		vim.api.nvim_buf_set_extmark(buf, state.ns, line0, 0, vim.tbl_extend("force", opts, { id = id }))
	else
		id = vim.api.nvim_buf_set_extmark(buf, state.ns, line0, 0, opts)
		state.extmarks_by_buf_line[buf][line0] = id
	end
	state.last_msg_by_buf_line[buf][line0] = entry
end

function M.render_message(msg)
	if not (msg and msg.file and msg.line) then
		log.debug("render_message: missing file/line", msg)
		return
	end

	local kind = msg.kind or "log"
	local full_payload = stringify_args(msg.args)
	if not filters.should_render(msg, full_payload) then
		log.debug("render_message: filtered by project rules", msg)
		return
	end
	if not filters.severity_allows(kind, msg, full_payload) then
		log.debug("render_message: severity filtered by project rules", kind)
		return
	end

	local icon, hl = severity_icon(kind)
	local display_payload = truncate(full_payload, state.opts.max_len)
	icon, hl = apply_pattern_overrides(full_payload, icon, hl)
	local history_entry = msg._console_inline_history_entry
	if not history_entry then
		history_entry = {
			file = msg.file,
			original_line = msg.line,
			kind = kind,
			payload = full_payload,
			display_payload = display_payload,
			display = icon .. " " .. display_payload,
			text = icon .. " " .. display_payload,
			raw_args = msg.args,
			icon = icon,
			highlight = hl,
			timestamp = os.time(),
		}
		history.record(history_entry)
		msg._console_inline_history_entry = history_entry
	else
		history_entry.file = msg.file
		history_entry.original_line = msg.line
		history_entry.kind = kind
		history_entry.payload = full_payload
		history_entry.display_payload = display_payload
		history_entry.display = icon .. " " .. display_payload
		history_entry.text = icon .. " " .. display_payload
		history_entry.raw_args = msg.args
		history_entry.icon = icon
		history_entry.highlight = hl
		if not history_entry.timestamp then
			history_entry.timestamp = os.time()
		end
	end
	history_entry.count = 1
	history_entry.render_line = msg.line

	local remote = is_remote_path(msg.file)
	if remote then
		log.debug("render_message: remote path", msg.file)
	end

	local buf_module = require("console_inline.buf")
	local buf = buf_module.find_buf_by_path(msg.file)
	if not buf then
		log.debug("render_message: buffer not found for", msg.file)
		if state.opts.open_missing_files and not remote then
			buf = buf_module.ensure_buffer(msg.file)
			log.debug("render_message: opened missing file", msg.file)
		else
			if remote then
				log.debug("render_message: skipping queue for remote path", msg.file)
				return
			end
			log.debug("render_message: queueing message for", msg.file)
			local key = buf_module.canon(msg.file)
			state.queued_messages_by_file[key] = state.queued_messages_by_file[key] or {}
			table.insert(state.queued_messages_by_file[key], msg)
			return
		end
	end
	if not vim.api.nvim_buf_is_loaded(buf) then
		log.debug("render_message: buffer not loaded for", msg.file)
		local key = buf_module.canon(msg.file)
		state.queued_messages_by_file[key] = state.queued_messages_by_file[key] or {}
		table.insert(state.queued_messages_by_file[key], msg)
		return
	end

	local line0 = clamp_line(buf, (msg.line or 1) - 1)
	line0 = adjust_line(buf, line0)
	history_entry.render_line = line0 + 1
	history_entry.buf = buf

	state.last_msg_by_buf_line[buf] = state.last_msg_by_buf_line[buf] or {}
	local prev = state.last_msg_by_buf_line[buf][line0]
	local count = 1
	if prev and type(prev) == "table" and prev.payload == full_payload and prev.icon == icon then
		count = prev.count + 1
	end

	local prefix = count > 1 and (count .. "x ") or ""
	local display = icon .. " " .. prefix .. display_payload
	history_entry.count = count
	history_entry.display = display
	history_entry.text = display

	log.debug(
		string.format("set_line_text: buf=%s line=%d text=%s hl=%s count=%d", tostring(buf), line0, display, hl, count)
	)

	local entry = {
		text = display,
		payload = full_payload,
		icon = icon,
		count = count,
		raw_args = msg.args,
		highlight = hl,
	}
	set_line_text(buf, line0, entry, hl)
end

function M.clear_current_buffer()
	vim.api.nvim_buf_clear_namespace(0, state.ns, 0, -1)
	state.extmarks_by_buf_line[vim.api.nvim_get_current_buf()] = nil
	state.last_msg_by_buf_line[vim.api.nvim_get_current_buf()] = nil
end

function M.get_entry_at_cursor()
	local buf = vim.api.nvim_get_current_buf()
	local line0 = vim.api.nvim_win_get_cursor(0)[1] - 1
	return state.last_msg_by_buf_line[buf] and state.last_msg_by_buf_line[buf][line0]
end

function M.copy_current_line()
	local buf = vim.api.nvim_get_current_buf()
	local line0 = vim.api.nvim_win_get_cursor(0)[1] - 1
	local entry = state.last_msg_by_buf_line[buf] and state.last_msg_by_buf_line[buf][line0]
	local text = entry and (entry.text or entry)
	if text then
		vim.fn.setreg("+", text)
		vim.notify("console-inline: copied to clipboard")
	else
		vim.notify("console-inline: nothing to copy", vim.log.levels.WARN)
	end
end

return M
