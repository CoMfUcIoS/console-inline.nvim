local state = require("console_inline.state")
local compat = require("console_inline.compat")
local log = require("console_inline.log")

local M = {}

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

local function set_line_text(buf, line0, text, hl)
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
	state.last_msg_by_buf_line[buf][line0] = text
end

function M.render_message(msg)
	if not (msg and msg.file and msg.line) then
		log.debug("render_message: missing file/line", msg)
		return
	end
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
		state.queued_messages_by_file[msg.file] = state.queued_messages_by_file[msg.file] or {}
		table.insert(state.queued_messages_by_file[msg.file], msg)
		return
	end
	if state.opts.severity_filter and not state.opts.severity_filter[msg.kind or "log"] then
		log.debug("render_message: severity filtered", msg.kind)
		return
	end

	local icon, hl = severity_icon(msg.kind)
	local payload = stringify_args(msg.args)
	local text = icon .. " " .. truncate(payload, state.opts.max_len)
	local line0 = clamp_line(buf, (msg.line or 1) - 1)
	line0 = adjust_line(buf, line0)
	log.debug(string.format("set_line_text: buf=%s line=%d text=%s hl=%s", tostring(buf), line0, text, hl))
	set_line_text(buf, line0, text, hl)
end

function M.clear_current_buffer()
	vim.api.nvim_buf_clear_namespace(0, state.ns, 0, -1)
	state.extmarks_by_buf_line[vim.api.nvim_get_current_buf()] = nil
	state.last_msg_by_buf_line[vim.api.nvim_get_current_buf()] = nil
end

function M.copy_current_line()
	local buf = vim.api.nvim_get_current_buf()
	local line0 = vim.api.nvim_win_get_cursor(0)[1] - 1
	local t = state.last_msg_by_buf_line[buf] and state.last_msg_by_buf_line[buf][line0]
	if t then
		vim.fn.setreg("+", t)
		vim.notify("console-inline: copied to clipboard")
	else
		vim.notify("console-inline: nothing to copy", vim.log.levels.WARN)
	end
end

return M
