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

local function find_network_line(buf, line0, network)
	if type(network) ~= "table" then
		return nil
	end
	local max = vim.api.nvim_buf_line_count(buf)
	if max <= 0 then
		return nil
	end
	local function matches(line)
		if not line then
			return false
		end
		if network.type == "fetch" then
			if line:find("fetch%s*%(") or line:find("await%s+fetch") then
				return true
			end
		elseif network.type == "xhr" then
			if line:find("XMLHttpRequest") or line:find(":open%s*%(") or line:find(":send%s*%(") then
				return true
			end
		end
		local url = network.url
		if type(url) == "string" and #url >= 3 then
			local plain = url
			plain = plain:gsub("^[^%w]+", "")
			if #plain >= 3 and line:find(plain, 1, true) then
				return true
			end
		end
		return false
	end
	local start = math.max(0, line0)
	local finish = math.min(max - 1, line0 + 20)
	for i = start, finish do
		local line = vim.api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
		if matches(line) then
			return i
		end
	end
	local back_start = math.max(0, line0 - 5)
	for i = back_start, line0 - 1 do
		local line = vim.api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
		if matches(line) then
			return i
		end
	end
	return nil
end

local function network_icon(kind)
	if kind == "error" then
		return "⇣", "DiagnosticError"
	end
	if kind == "warn" then
		return "⇣", "DiagnosticWarn"
	end
	return "⇢", "DiagnosticInfo"
end

local function build_popup_lines(entry)
	local formatter = state.opts.popup_formatter or require("console_inline.format").default
	local ok, result = pcall(formatter, entry)
	local lines = {}
	if ok and type(result) == "table" then
		for _, line in ipairs(result) do
			lines[#lines + 1] = tostring(line)
		end
	end
	if #lines == 0 then
		local fallback = entry.payload or entry.text or ""
		if type(fallback) == "string" and fallback ~= "" then
			for _, line in ipairs(vim.split(fallback, "\n", true)) do
				lines[#lines + 1] = tostring(line)
			end
		end
	end
	if entry.count and entry.count > 1 then
		table.insert(lines, 1, string.format("[%dx repeats]", entry.count))
	end
	if #lines == 0 then
		lines = { "<empty>" }
	end
	return lines
end

local function popup_dimensions(lines)
	local width = 0
	for _, line in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(line))
	end
	local max_columns = math.max(1, math.floor(vim.o.columns * 0.8))
	local max_lines = math.max(1, math.floor(vim.o.lines * 0.5))
	width = math.min(math.max(width + 4, 40), max_columns)
	local height = math.min(#lines, max_lines)
	if height <= 0 then
		height = 1
	end
	return width, height
end

local function open_popup(entry, opts)
	local lines = build_popup_lines(entry)
	local width, height = popup_dimensions(lines)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	local win_opts = {
		relative = opts.relative or "cursor",
		row = opts.row or 1,
		col = opts.col or 0,
		width = width,
		height = height,
		style = opts.style or "minimal",
		border = opts.border or "rounded",
		focusable = opts.focusable ~= false,
		noautocmd = opts.noautocmd ~= false,
	}
	if opts.anchor then
		win_opts.anchor = opts.anchor
	end
	if opts.zindex then
		win_opts.zindex = opts.zindex
	end
	local enter = opts.enter
	if enter == nil then
		enter = true
	end
	local ok, win = pcall(vim.api.nvim_open_win, buf, enter, win_opts)
	if not ok then
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
		log.debug("open_popup failed", win)
		return nil
	end
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	return {
		win = win,
		buf = buf,
		lines = lines,
		config = win_opts,
		entry = entry,
	}
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

local function candidate_paths(file)
	if type(file) ~= "string" or file == "" then
		return {}
	end
	local seen = {}
	local items = {}
	local function add(path)
		if not seen[path] then
			seen[path] = true
			items[#items + 1] = path
		end
	end
	add(file)
	if file:match("%.js$") then
		add(file:gsub("%.js$", ".ts"))
		add(file:gsub("%.js$", ".tsx"))
	elseif file:match("%.ts$") then
		add(file:gsub("%.ts$", ".tsx"))
		add(file:gsub("%.ts$", ".js"))
	elseif file:match("%.jsx$") then
		add(file:gsub("%.jsx$", ".tsx"))
	elseif file:match("%.tsx$") then
		add(file:gsub("%.tsx$", ".ts"))
		add(file:gsub("%.tsx$", ".jsx"))
	end
	return items
end

local function line_contains_console(line)
	return line and line:find("console%.") ~= nil
end

local function collect_terms(args, timer)
	local terms = {}
	local function push(term)
		if type(term) ~= "string" then
			return
		end
		local trimmed = term:match("^%s*(.-)%s*$") or term
		if #trimmed >= 3 then
			terms[#terms + 1] = trimmed
		end
	end
	if timer and type(timer.label) == "string" then
		push(timer.label)
	end
	if type(args) == "table" then
		for _, value in ipairs(args) do
			if type(value) == "string" then
				push(value)
				break
			end
		end
	end
	return terms
end

local function gather_candidates(buf, method, terms)
	local max = vim.api.nvim_buf_line_count(buf)
	local method_literal = method and ("console." .. method) or nil
	local results = {}
	local method_match_found = false
	local term_match_found = false
	for idx = 0, max - 1 do
		local line = vim.api.nvim_buf_get_lines(buf, idx, idx + 1, false)[1]
		if line_contains_console(line) then
			local col = line:find("console%.") or 1
			local method_match = false
			if method_literal then
				local mcol = line:find(method_literal, 1, true)
				if mcol then
					method_match = true
					col = mcol
				end
			end
			local term_match = false
			if terms and #terms > 0 then
				for _, term in ipairs(terms) do
					if line:find(term, 1, true) then
						term_match = true
						break
					end
				end
			end
			if method_match then
				method_match_found = true
			end
			if term_match then
				term_match_found = true
			end
			results[#results + 1] = {
				line = idx,
				column = col - 1,
				method_match = method_match,
				term_match = term_match,
			}
		end
	end
	if method_literal and method_match_found then
		local filtered = {}
		for _, item in ipairs(results) do
			if item.method_match then
				filtered[#filtered + 1] = item
			end
		end
		if #filtered > 0 then
			results = filtered
		end
	end
	if terms and #terms > 0 and term_match_found then
		local filtered = {}
		for _, item in ipairs(results) do
			if item.term_match then
				filtered[#filtered + 1] = item
			end
		end
		if #filtered > 0 then
			results = filtered
		end
	end
	return results
end

local function adjust_line(buf, line0, method, args, timer, column, network)
	local network_line = find_network_line(buf, line0, network)
	if network_line ~= nil then
		return network_line
	end
	local candidates = gather_candidates(buf, method, collect_terms(args, timer))
	if #candidates == 0 then
		return line0
	end
	local target_col = column and (column - 1) or nil
	local best = candidates[1]
	local best_score = math.huge
	for _, candidate in ipairs(candidates) do
		local line_dist = math.abs(candidate.line - line0)
		local col_dist = 0
		if target_col then
			col_dist = math.abs((candidate.column or 0) - target_col)
		end
		local score = line_dist * 1000 + col_dist
		if score < best_score then
			best_score = score
			best = candidate
		end
	end
	return best.line or line0
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

	if is_remote_path(msg.file) then
		log.debug("render_message: remote path", msg.file)
		return
	end

	local icon, hl
	if msg.network then
		icon, hl = network_icon(kind)
	else
		icon, hl = severity_icon(kind)
	end
	local display_payload = msg.network and msg.network.summary or full_payload
	icon, hl = apply_pattern_overrides(display_payload or full_payload, icon, hl)
	if type(msg.trace) == "table" and #msg.trace > 0 then
		local first = msg.trace[1]
		if msg.args == nil or #msg.args == 0 then
			display_payload = first
		else
			display_payload = display_payload .. " → " .. first
		end
	elseif type(msg.trace) == "table" and #msg.trace == 0 then
		display_payload = "trace"
	end
	local timer_info = msg.time
	if type(timer_info) == "table" then
		local label = timer_info.label or "timer"
		if timer_info.duration_ms then
			local ms = tonumber(timer_info.duration_ms) or 0
			display_payload = string.format("%s: %.3f ms", label, ms)
			icon = "⏱"
			hl = "DiagnosticInfo"
		elseif timer_info.missing then
			display_payload = string.format("Timer '%s' not found", label)
			icon = "⚠"
			hl = "DiagnosticWarn"
		else
			display_payload = label
			icon = "⏱"
			hl = "DiagnosticInfo"
		end
	end
	display_payload = truncate(display_payload, state.opts.max_len)
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
			method = msg.method,
			trace = msg.trace,
			time = msg.time,
			network = msg.network,
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
		history_entry.method = msg.method
		history_entry.trace = msg.trace
		history_entry.time = msg.time
		history_entry.network = msg.network
		if not history_entry.timestamp then
			history_entry.timestamp = os.time()
		end
	end
	history_entry.count = 1
	history_entry.render_line = msg.line

	local buf_module = require("console_inline.buf")
	local buf = nil
	for _, path in ipairs(candidate_paths(msg.file)) do
		buf = buf_module.find_buf_by_path(path)
		if buf then
			if path ~= msg.file then
				msg.file = path
			end
			break
		end
	end
	if not buf then
		log.debug("render_message: buffer not found for", msg.file)
		if state.opts.open_missing_files then
			buf = buf_module.ensure_buffer(msg.file)
			log.debug("render_message: opened missing file", msg.file)
		else
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
	line0 = adjust_line(buf, line0, msg.method, msg.args, msg.time, msg.column, msg.network)
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
		method = msg.method,
		trace = msg.trace,
		time = msg.time,
	}
	set_line_text(buf, line0, entry, hl)
	if state.hover_popup and state.hover_popup.entry == history_entry then
		M.refresh_hover_popup(history_entry)
	end
end

function M.clear_current_buffer()
	vim.api.nvim_buf_clear_namespace(0, state.ns, 0, -1)
	state.extmarks_by_buf_line[vim.api.nvim_get_current_buf()] = nil
	state.last_msg_by_buf_line[vim.api.nvim_get_current_buf()] = nil
	if state.hover_popup and state.hover_popup.source_buf == vim.api.nvim_get_current_buf() then
		M.close_hover_popup()
	end
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

function M.open_entry_popup(entry, opts)
	if not entry then
		return nil
	end
	opts = opts or {}
	local popup = open_popup(entry, opts)
	if not popup then
		return nil
	end
	if opts.interactive ~= false then
		local function close()
			if vim.api.nvim_win_is_valid(popup.win) then
				vim.api.nvim_win_close(popup.win, true)
			end
		end
		vim.keymap.set("n", "q", close, { buffer = popup.buf, nowait = true })
		vim.keymap.set("n", "<Esc>", close, { buffer = popup.buf, nowait = true })
	end
	return popup
end

function M.open_standalone_popup(entry)
	M.close_hover_popup()
	return M.open_entry_popup(entry, {
		interactive = true,
		focusable = true,
		enter = true,
		noautocmd = false,
		zindex = 80,
	})
end

function M.close_hover_popup()
	local hover = state.hover_popup
	if not hover then
		return
	end
	if hover.win and vim.api.nvim_win_is_valid(hover.win) then
		vim.api.nvim_win_close(hover.win, true)
	end
	if hover.buf and vim.api.nvim_buf_is_valid(hover.buf) then
		pcall(vim.api.nvim_buf_delete, hover.buf, { force = true })
	end
	state.hover_popup = nil
end

function M.show_hover_popup(entry, opts)
	local hover_opts = state.opts.hover or {}
	if hover_opts.enabled == false then
		return nil
	end
	local config = vim.tbl_extend("force", {
		interactive = false,
		focusable = hover_opts.focusable,
		border = hover_opts.border,
		relative = hover_opts.relative,
		row = hover_opts.row,
		col = hover_opts.col,
		enter = false,
		noautocmd = true,
		zindex = hover_opts.zindex or 60,
	}, opts or {})
	local popup = M.open_entry_popup(entry, config)
	if not popup then
		return nil
	end
	state.hover_popup = {
		win = popup.win,
		buf = popup.buf,
		entry = entry,
		config = config,
		source_buf = vim.api.nvim_get_current_buf(),
		line0 = vim.api.nvim_win_get_cursor(0)[1] - 1,
	}
	return popup.win
end

function M.refresh_hover_popup(entry)
	local hover = state.hover_popup
	if not hover or not hover.entry then
		return
	end
	if entry and hover.entry ~= entry then
		return
	end
	local entry_ref = hover.entry
	local config = hover.config
	M.close_hover_popup()
	if entry_ref then
		M.show_hover_popup(entry_ref, config)
	end
end

function M.maybe_show_hover()
	local hover_opts = state.opts.hover or {}
	if hover_opts.enabled == false then
		return
	end
	if vim.tbl_contains({ "nofile", "prompt", "terminal" }, vim.bo.buftype) then
		M.close_hover_popup()
		return
	end
	local mode = vim.api.nvim_get_mode().mode
	if mode:match("^i") or mode:match("^v") or mode == "R" then
		M.close_hover_popup()
		return
	end
	local buf = vim.api.nvim_get_current_buf()
	local line0 = vim.api.nvim_win_get_cursor(0)[1] - 1
	local entry = state.last_msg_by_buf_line[buf] and state.last_msg_by_buf_line[buf][line0]
	if not entry then
		M.close_hover_popup()
		return
	end
	local hover = state.hover_popup
	if hover and hover.entry == entry and hover.win and vim.api.nvim_win_is_valid(hover.win) then
		return
	end
	M.close_hover_popup()
	M.show_hover_popup(entry)
end

return M
