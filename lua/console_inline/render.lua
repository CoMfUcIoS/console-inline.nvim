local state = require("console_inline.state")
local compat = require("console_inline.compat")

local M = {}

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
		return
	end
	local buf = require("console_inline.buf").find_buf_by_path(msg.file)
	if not buf then
		if state.opts.open_missing_files then
			buf = require("console_inline.buf").ensure_buffer(msg.file)
		else
            -- Queue the message for later rendering when buffer is loaded
            state.queued_messages_by_file[msg.file] = state.queued_messages_by_file[msg.file] or {}
            table.insert(state.queued_messages_by_file[msg.file], msg)
            return
		end
	end
    if not vim.api.nvim_buf_is_loaded(buf) then
        -- Queue the message for later rendering when buffer is loaded
        state.queued_messages_by_file[msg.file] = state.queued_messages_by_file[msg.file] or {}
        table.insert(state.queued_messages_by_file[msg.file], msg)
        return
	end
	if not state.opts.severity_filter[msg.kind or "log"] then
		return
	end

	local icon, hl = severity_icon(msg.kind)
	local payload = stringify_args(msg.args)
	local text = icon .. " " .. truncate(payload, state.opts.max_len)
	local line0 = math.max(0, (msg.line or 1) - 1)
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
