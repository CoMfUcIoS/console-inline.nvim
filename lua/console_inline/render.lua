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

-- Improved network line resolution: search outward from the reported line first,
-- then fall back to full file scan. Avoids anchoring to the first fetch/xhr globally.
local function find_network_line(buf, line0, network)
	if type(network) ~= "table" then
		return nil
	end
	local max = vim.api.nvim_buf_line_count(buf)
	if max <= 0 then
		return nil
	end
	local function matches(line)
		if not line or line == "" then
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
			local plain = url:gsub("^[^%w]+", "")
			if #plain >= 3 and line:find(plain, 1, true) then
				return true
			end
		end
		return false
	end
	line0 = type(line0) == "number" and math.max(0, math.min(max - 1, line0)) or 0
	local radius = 80 -- search window around the incoming line first
	for offset = 0, radius do
		local up = line0 - offset
		local down = line0 + offset
		if up >= 0 then
			local line_up = vim.api.nvim_buf_get_lines(buf, up, up + 1, false)[1]
			if matches(line_up) then
				return up
			end
		end
		if down < max and offset > 0 then
			local line_down = vim.api.nvim_buf_get_lines(buf, down, down + 1, false)[1]
			if matches(line_down) then
				return down
			end
		end
	end
	-- fallback full scan (rare)
	for i = 0, max - 1 do
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

local function line_contains_console_method(line, method)
	if not line or not method then
		return false
	end
	-- Match console.method, handling both full calls and inline arrow functions
	local pattern = "console%." .. method
	return line:find(pattern, 1, true) ~= nil
end

-- Extract candidate anchor terms from arguments/timer label with basic stop-word filtering.
local stopwords = {
	["error"] = true,
	["warn"] = true,
	["warning"] = true,
	["info"] = true,
	["log"] = true,
	["message"] = true,
	["duration"] = true,
	["label"] = true,
	["fetch"] = true,
	["open"] = true,
	["send"] = true,
}
local function collect_terms(args, timer)
	local terms = {}
	local seen_terms = {}
	local function push(term)
		if type(term) ~= "string" then
			return
		end
		local trimmed = term:match("^%s*(.-)%s*$") or term
		if trimmed:find("\n") then
			return
		end
		if #trimmed < 3 or #trimmed > 120 then
			return
		end
		local lower = trimmed:lower()
		if stopwords[lower] and #trimmed < 8 then
			return
		end -- ignore generic short stopwords
		if not seen_terms[trimmed] then
			terms[#terms + 1] = trimmed
			seen_terms[trimmed] = true
		end
	end
	if timer and type(timer.label) == "string" then
		push(timer.label)
	end
	local function extract(value, depth)
		if depth > 4 then
			return
		end
		if type(value) == "string" then
			push(value)
		elseif type(value) == "table" then
			local seen = 0
			for _, inner in pairs(value) do
				if seen >= 6 then
					break
				end
				extract(inner, depth + 1)
				seen = seen + 1
			end
		end
	end
	if type(args) == "table" then
		for _, value in ipairs(args) do
			extract(value, 0)
		end
	end
	return terms
end

local function line_contains_term(buf, line0, terms)
	if type(terms) ~= "table" or #terms == 0 then
		return false
	end
	if type(line0) ~= "number" then
		return false
	end
	local ok, line = pcall(vim.api.nvim_buf_get_lines, buf, line0, line0 + 1, false)
	if not ok or type(line) ~= "table" then
		return false
	end
	local text = line[1]
	if type(text) ~= "string" or text == "" then
		return false
	end
	for _, term in ipairs(terms) do
		if type(term) == "string" and term ~= "" and text:find(term, 1, true) then
			return true
		end
	end
	return false
end

local function line_contains_error_pattern(line)
	if not line or line == "" then
		return false
	end
	-- Match throw statements (but not in console.* calls)
	if (line:find("throw%s") or line:find("throw%(")) and not line:find("console%.") then
		return true
	end
	-- Match Error construction (new Error, Promise.reject, etc.) - but not in console.* calls
	if not line:find("console%.") then
		if line:find("new%s+Error") or line:find("new%s+TypeError") or line:find("new%s+RangeError") then
			return true
		end
		if line:find("Promise%.reject") or line:find("Promise%.Reject") then
			return true
		end
		-- Match error instantiation in general (but not as console.error argument)
		if line:find("Error%(") and not line:find("console%.error") then
			return true
		end
	end
	return false
end

-- New candidate collection + scoring heuristic.
local function gather_candidates(buf, base_line, method, terms)
	local do_bench = state.opts.benchmark_enabled ~= false and state.opts.benchmark_enabled
	local t_start = do_bench and vim.loop.hrtime() or nil
	local ok_index, index = pcall(require, "console_inline.index")
	if state.opts.use_index ~= false and ok_index and state.buffer_index and state.buffer_index[buf] then
		local token_list = {}
		for _, t in ipairs(terms or {}) do
			token_list[#token_list + 1] = t:lower()
		end
		local lines = index.lookup(buf, token_list, method)
		local results = {}
		local method_literal = (
			type(method) == "string"
			and method ~= ""
			and (method:match("^[%w_]+$") and ("console." .. method) or nil)
		) or nil
		for _, idx in ipairs(lines or {}) do
			local line = vim.api.nvim_buf_get_lines(buf, idx, idx + 1, false)[1]
			if line and line ~= "" then
				local has_console = line_contains_console(line)
				local col = 1
				local method_match = false
				if has_console then
					local cpos = line:find("console%.")
					if cpos then
						col = cpos
					end
					if method_literal then
						local mcol = line:find(method_literal, 1, true)
						if mcol then
							method_match = true
							col = mcol
						end
					end
				end
				local term_hits = 0
				local first_term_col = nil
				for _, term in ipairs(terms or {}) do
					local pos = line:find(term, 1, true)
					if pos then
						term_hits = term_hits + 1
						first_term_col = first_term_col and math.min(first_term_col, pos) or pos
					end
				end
				local is_comment = line:match("^%s*//") or line:match("^%s*%-%-") or line:match("^%s*/%*")
				if first_term_col then
					col = first_term_col
				end
				local line_dist = math.abs(idx - base_line)
				local score = line_dist * 10
				if method_match then
					score = score - 1000
				end
				if has_console then
					score = score - 200
				end
				if term_hits > 0 then
					score = score - (term_hits * 50)
				end
				if is_comment and not has_console then
					score = score + 200
				end
				results[#results + 1] = {
					line = idx,
					column = col - 1,
					method_match = method_match,
					term_hits = term_hits,
					is_comment = is_comment and true or false,
					score = score,
				}
			end
		end
		if do_bench and t_start then
			local elapsed = vim.loop.hrtime() - t_start
			local stats = require("console_inline.state").benchmark_stats
			stats.total_index_time_ns = stats.total_index_time_ns + elapsed
			stats.count_index = stats.count_index + 1
		end
		return results
	end
	-- Fallback to full scan
	local max = vim.api.nvim_buf_line_count(buf)
	local results = {}
	local method_literal = (
		type(method) == "string"
		and method ~= ""
		and (method:match("^[%w_]+$") and ("console." .. method) or nil)
	) or nil
	local is_runtime_error = method and (method:find("onerror") or method:find("rejection") or method:find("Exception"))
	for idx = 0, max - 1 do
		local line = vim.api.nvim_buf_get_lines(buf, idx, idx + 1, false)[1]
		if line and line ~= "" then
			local has_console = line_contains_console(line)
			local has_error_pattern = is_runtime_error and line_contains_error_pattern(line)
			local col = 1
			local method_match = false
			if has_console then
				local cpos = line:find("console%.")
				if cpos then
					col = cpos
				end
				if method_literal then
					local mcol = line:find(method_literal, 1, true)
					if mcol then
						method_match = true
						col = mcol
					end
				end
			end
			local term_hits = 0
			local first_term_col = nil
			for _, term in ipairs(terms or {}) do
				local pos = line:find(term, 1, true)
				if pos then
					term_hits = term_hits + 1
					first_term_col = first_term_col and math.min(first_term_col, pos) or pos
				end
			end
			local is_comment = line:match("^%s*//") or line:match("^%s*%-%-") or line:match("^%s*/%*")
			if first_term_col then
				col = first_term_col
			end
			-- Include line if it has console, terms, or error patterns for runtime errors
			if has_console or term_hits > 0 or has_error_pattern then
				local line_dist = math.abs(idx - base_line)
				local score = line_dist * 10
				if method_match then
					score = score - 1000
				end
				if has_console then
					score = score - 200
				end
				if term_hits > 0 then
					score = score - (term_hits * 50)
				end
				if has_error_pattern then
					score = score - 300
				end -- Boost error patterns
				if is_comment and not has_console then
					score = score + 200
				end
				results[#results + 1] = {
					line = idx,
					column = col - 1,
					method_match = method_match,
					term_hits = term_hits,
					is_comment = is_comment and true or false,
					score = score,
				}
			end
		end
	end
	if do_bench and t_start then
		local elapsed = vim.loop.hrtime() - t_start
		local stats = require("console_inline.state").benchmark_stats
		stats.total_scan_time_ns = stats.total_scan_time_ns + elapsed
		stats.count_scan = stats.count_scan + 1
	end
	return results
end

local function adjust_line(buf, line0, method, args, timer, column, network, terms)
	-- network override (proximity based)
	local network_line = find_network_line(buf, line0, network)
	if network_line ~= nil then
		return network_line
	end
	terms = terms or collect_terms(args, timer)
	local do_bench = state.opts.benchmark_enabled ~= false and state.opts.benchmark_enabled
	local t_start = do_bench and vim.loop.hrtime() or nil
	local candidates = gather_candidates(buf, line0, method, terms)

	-- For runtime errors with no candidates, do a focused search for error patterns
	local is_runtime_error = method and (method:find("onerror") or method:find("rejection") or method:find("Exception"))
	if #candidates == 0 and is_runtime_error then
		local max = vim.api.nvim_buf_line_count(buf)
		local search_radius = math.min(100, max)
		for offset = 0, search_radius do
			for _, dir in ipairs({ -1, 1 }) do
				local check_line = line0 + (offset * dir)
				if check_line >= 0 and check_line < max then
					local line_text = vim.api.nvim_buf_get_lines(buf, check_line, check_line + 1, false)[1]
					if line_text and line_contains_error_pattern(line_text) then
						candidates[#candidates + 1] = {
							line = check_line,
							column = 0,
							method_match = false,
							term_hits = 0,
							is_comment = false,
							score = math.abs(check_line - line0) * 10 - 400, -- Strong preference
						}
					end
				end
			end
		end
	end

	if #candidates == 0 then
		return line0
	end
	-- restrict to radius around base_line if we have credible base position
	local max = vim.api.nvim_buf_line_count(buf)
	local radius = math.max(50, math.floor(max * 0.05))
	local filtered = {}
	for _, c in ipairs(candidates) do
		if math.abs(c.line - line0) <= radius then
			filtered[#filtered + 1] = c
		end
	end
	if #filtered > 0 then
		candidates = filtered
	end
	local target_col = column and (column - 1) or nil
	local best = nil
	local best_score = math.huge
	local ts_mod = nil
	local ts_ctx_base = nil
	if state.opts.use_treesitter then
		local ok_ts, mod = pcall(require, "console_inline.treesitter")
		if ok_ts then
			ts_mod = mod
			ts_ctx_base = mod.context_for(buf, line0)
		end
	end
	for _, c in ipairs(candidates) do
		local score = c.score
		if target_col then
			local col_dist = math.abs((c.column or 0) - target_col)
			score = score + col_dist * 2
		end
		if ts_mod then
			local ctx = ts_mod.context_for(buf, c.line)
			if ctx and ts_ctx_base then
				-- Favor same function/class blocks: subtract a bonus
				if
					ctx.function_name
					and ts_ctx_base.function_name
					and ctx.function_name == ts_ctx_base.function_name
				then
					score = score - 120
				end
				if ctx.class_name and ts_ctx_base.class_name and ctx.class_name == ts_ctx_base.class_name then
					score = score - 80
				end
			end
			-- Favor explicit console call nodes when method matches
			if ctx and ctx.has_console_call and method then
				score = score - 40
			end
			if ctx then
				if ctx.has_fetch_call then
					-- Slight boost for network-related resolution proximity
					score = score - 30
				end
				if ctx.has_error_new or ctx.has_throw_stmt or ctx.has_promise_reject then
					-- Emphasize error-related lines when method involves error/warn
					if method == "error" or method == "warn" then
						score = score - 50
					end
					-- Strong boost for runtime errors to prefer actual throw/error sites
					if method and (method:find("onerror") or method:find("rejection") or method:find("Exception")) then
						score = score - 500
					end
				end
				if ctx.console_method_name and method and ctx.console_method_name == method then
					-- Direct method name alignment
					score = score - 25
				end
			end
		end
		if score < best_score then
			best_score = score
			best = c
		end
	end
	local resolved = (best and best.line) or line0

	log.debug(
		string.format(
			"adjust_line result: base=%d resolved=%d candidates=%d best_score=%.1f method=%s",
			line0,
			resolved,
			#candidates,
			best_score,
			tostring(method)
		)
	)

	if do_bench and t_start then
		local elapsed = vim.loop.hrtime() - t_start
		local stats = state.benchmark_stats
		local rec = {
			resolved = resolved,
			base = line0,
			candidate_count = #candidates,
			terms = terms,
			method = method,
			time_ns = elapsed,
		}
		local entries = stats.entries
		entries[#entries + 1] = rec
		if #entries > stats.max_entries then
			table.remove(entries, 1)
		end
	end
	return resolved
end

local function set_line_text(buf, line0, entry, hl)
	local text = entry.text
	state.extmarks_by_buf_line[buf] = state.extmarks_by_buf_line[buf] or {}
	state.last_msg_by_buf_line[buf] = state.last_msg_by_buf_line[buf] or {}
	local id = state.extmarks_by_buf_line[buf][line0]

	-- Get position indicator info
	local current_idx, total_count = history.get_position_per_line(buf, line0)
	local has_position = current_idx and total_count and total_count > 1

	-- Build virt_text with type-aware highlighting if enabled
	local virt_text
	if state.opts.type_highlighting ~= false then
		local format_mod = require("console_inline.format")
		local ok, segments = pcall(format_mod.inline_typed, entry)
		if ok and type(segments) == "table" and #segments > 0 then
			virt_text = {}
			-- Add position indicator as first segment if needed
			if has_position then
				virt_text[#virt_text + 1] = { string.format("[%d/%d] ", current_idx, total_count), "Comment" }
			end
			-- Add type-highlighted segments
			for _, seg in ipairs(segments) do
				if seg.text and seg.text ~= "" then
					virt_text[#virt_text + 1] = { seg.text, seg.hl or hl }
				end
			end
		else
			-- Fallback: single segment with position indicator in text if needed
			if has_position then
				virt_text = { { string.format("[%d/%d] %s", current_idx, total_count, text), hl } }
			else
				virt_text = { { text, hl } }
			end
		end
	else
		-- Type highlighting disabled: add position indicator to text
		if has_position then
			virt_text = { { string.format("[%d/%d] %s", current_idx, total_count, text), hl } }
		else
			virt_text = { { text, hl } }
		end
	end

	local opts = {
		virt_text = virt_text,
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

	-- Capture transformed coordinates before any override.
	local transformed_file = msg.file
	local transformed_line = msg.line
	local transformed_column = msg.column

	-- Prefer original source if service emitted remapped coordinates and option enabled.
	if state.opts.prefer_original_source and msg.original_file and msg.original_line then
		if type(msg.original_file) == "string" and msg.original_file ~= "" then
			msg.file = msg.original_file
		end
		local oline = tonumber(msg.original_line)
		if oline and oline > 0 then
			msg.line = oline
		end
		if msg.original_column then
			local ocol = tonumber(msg.original_column)
			if ocol and ocol > 0 then
				msg.column = ocol
			end
		end
	end

	local kind = msg.kind or "log"
	local full_payload = stringify_args(msg.args)
	-- Track source map resolution status counters; handle transitions.
	if type(msg.mapping_status) == "string" then
		local ms = msg.mapping_status
		local stats = state.map_stats
		if stats then
			local transition = msg.mapping_status_transition
			if transition == "pending->hit" then
				if stats.pending > 0 then
					stats.pending = stats.pending - 1
				end
				stats.hit = stats.hit + 1
			else
				if ms == "hit" then
					stats.hit = stats.hit + 1
				elseif ms == "miss" then
					stats.miss = stats.miss + 1
				elseif ms == "pending" then
					stats.pending = stats.pending + 1
				end
			end
		end
	end
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
			transformed_file = transformed_file,
			transformed_line = transformed_line,
			transformed_column = transformed_column,
			original_file = msg.original_file or msg.file,
			original_column = msg.original_column or msg.column,
			mapping_status = msg.mapping_status,
			timestamp = os.time(),
		}
		history.record(history_entry)
		msg._console_inline_history_entry = history_entry
	else
		history_entry.file = msg.file
		history_entry.original_line = msg.line
		history_entry.transformed_file = transformed_file
		history_entry.transformed_line = transformed_line
		history_entry.transformed_column = transformed_column
		history_entry.original_file = msg.original_file or msg.file
		history_entry.original_column = msg.original_column or msg.column
		history_entry.mapping_status = msg.mapping_status
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

	local base_line = clamp_line(buf, (msg.line or 1) - 1)
	local terms = collect_terms(msg.args, msg.time)
	local terms_count = terms and #terms or 0
	local method = type(msg.method) == "string" and msg.method or nil
	local is_runtime_error = false
	local window_or_process = false
	if method then
		if method:find("^window%.") or method:find("^process%.") then
			window_or_process = true
			-- Runtime errors: error/rejection/Exception handlers
			if method:find("error") or method:find("rejection") or method:find("Exception") then
				is_runtime_error = true
			end
		end
	end

	log.debug(
		string.format(
			"render_message positioning: file=%s msg.line=%d base_line=%d (0-indexed) method=%s is_runtime_error=%s terms_count=%d",
			msg.file or "nil",
			msg.line or 0,
			base_line,
			method or "nil",
			tostring(is_runtime_error),
			terms_count
		)
	)

	-- For runtime errors, search nearby lines for actual error patterns
	-- Stack traces sometimes point to the callback setup rather than the throw line
	local line0 = base_line
	if is_runtime_error then
		local base_line_text = vim.api.nvim_buf_get_lines(buf, base_line, base_line + 1, false)[1]
		log.debug(
			string.format(
				"Runtime error base line %d (0-indexed) = line %d (1-indexed): '%s'",
				base_line,
				base_line + 1,
				base_line_text or "nil"
			)
		)

		if base_line_text and line_contains_error_pattern(base_line_text) then
			-- Base line has error pattern, use it
			log.debug("Runtime error: base line contains error pattern, using it")
			line0 = base_line
		else
			-- For async errors (setTimeout/setInterval callbacks), search FORWARD first
			-- since the base line might point to the setTimeout call line
			-- Skip caught errors in try-catch blocks by preferring patterns farther forward
			log.debug("Runtime error: base line lacks error pattern, searching nearby (forward then backward)")
			local found = false
			local max = vim.api.nvim_buf_line_count(buf)
			local candidates_found = {}

			-- Try Tree-sitter first if available
			local use_ts = state.opts.use_treesitter ~= false
			local has_ts, ts_mod = pcall(require, "console_inline.treesitter")
			if use_ts and has_ts then
				-- Collect Tree-sitter contexts for forward lines
				for offset = 1, 30 do
					local check_line = base_line + offset
					if check_line >= 0 and check_line < max then
						local ctx = ts_mod.context_for(buf, check_line)
						if ctx and (ctx.has_throw_stmt or ctx.has_error_new or ctx.has_promise_reject) then
							table.insert(candidates_found, { line = check_line, offset = offset, from_ts = true })
						end
					end
				end
			end -- If Tree-sitter didn't find anything, fall back to regex
			if #candidates_found == 0 then
				for offset = 1, 30 do
					local check_line = base_line + offset
					if check_line >= 0 and check_line < max then
						local line_text = vim.api.nvim_buf_get_lines(buf, check_line, check_line + 1, false)[1]
						if line_text and line_contains_error_pattern(line_text) then
							table.insert(candidates_found, { line = check_line, offset = offset, from_ts = false })
						end
					end
				end
			end

			-- Prefer the LAST match (farthest forward) as it's more likely to be in the actual async callback
			-- Errors in try-catch blocks tend to appear earlier in the file
			if #candidates_found > 0 then
				local best = candidates_found[#candidates_found]
				local method_str = best.from_ts and "Tree-sitter" or "regex"
				log.debug(
					string.format(
						"Runtime error: found %d error patterns (%s), using farthest at line %d (offset +%d)",
						#candidates_found,
						method_str,
						best.line,
						best.offset
					)
				)
				line0 = best.line
				found = true
			end

			-- If not found forward, search backward
			if not found then
				for offset = 1, 10 do
					local check_line = base_line - offset
					if check_line >= 0 and check_line < max then
						local line_text = vim.api.nvim_buf_get_lines(buf, check_line, check_line + 1, false)[1]
						if line_text and line_contains_error_pattern(line_text) then
							log.debug(
								string.format(
									"Runtime error: found error pattern at line %d (offset -%d)",
									check_line,
									offset
								)
							)
							line0 = check_line
							found = true
							break
						end
					end
				end
			end

			if not found then
				log.debug("Runtime error: no error pattern found nearby, using base line")
				line0 = base_line
			end
		end
	elseif window_or_process and terms_count == 0 then
		-- Non-error window/process methods without terms shouldn't adjust
		line0 = base_line
	else
		-- Normal console.log/etc - use full adjustment logic
		-- For console methods, check if base line already has the exact console call before adjusting
		local skip_adjustment = false
		if
			method
			and (
				method == "error"
				or method == "warn"
				or method == "log"
				or method == "info"
				or method == "trace"
				or method == "timeEnd"
				or method == "timeLog"
			)
		then
			local base_text = vim.api.nvim_buf_get_lines(buf, base_line, base_line + 1, false)[1]
			if base_text and line_contains_console_method(base_text, method) then
				skip_adjustment = true
				log.debug(
					string.format("console.%s: base line contains console.%s call, skipping adjustment", method, method)
				)
			end
		end

		local adjusted_line
		if skip_adjustment then
			adjusted_line = base_line
		else
			adjusted_line = adjust_line(buf, base_line, msg.method, msg.args, msg.time, msg.column, msg.network, terms)
		end
		if window_or_process and terms_count > 0 and adjusted_line ~= base_line then
			if not line_contains_term(buf, adjusted_line, terms) then
				adjusted_line = base_line
			end
		end
		line0 = adjusted_line
	end
	history_entry.render_line = line0 + 1
	history_entry.buf = buf

	-- Create entry without count prefix (for clean history cycling)
	local base_display = icon .. " " .. display_payload

	local entry = {
		text = base_display,
		payload = full_payload,
		icon = icon,
		count = 1,
		raw_args = msg.args,
		highlight = hl,
		method = msg.method,
		trace = msg.trace,
		time = msg.time,
	}

	-- Record in per-line history FIRST for cycling
	history.record_per_line(buf, line0, entry)

	-- Now render with the entry (set_line_text will add position indicator)
	set_line_text(buf, line0, entry, hl)

	-- Update history_entry for global history
	history_entry.count = 1
	history_entry.display = base_display
	history_entry.text = base_display

	log.debug(
		string.format("set_line_text: buf=%s line=%d text=%s hl=%s", tostring(buf), line0, base_display, hl)
	)
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

-- Refresh the virtual text display for a specific line with a new entry
function M.refresh_line_text(buf, lnum, entry)
	if not (buf and lnum and entry) then
		return
	end
	local hl = entry.highlight or "NonText"
	set_line_text(buf, lnum, entry, hl)
	if state.hover_popup and state.hover_popup.source_buf == buf then
		M.refresh_hover_popup(entry)
	end
end

return M
