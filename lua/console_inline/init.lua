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
local server = require("console_inline.server")
local render = require("console_inline.render")
local log = require("console_inline.log")
local buf_utils = require("console_inline.buf")

local css_color_events = {
	CursorMoved = true,
	CursorHold = true,
	BufEnter = true,
	CursorMovedI = true,
}

local function ensure_css_color_defaults(buf)
	if state.opts.suppress_css_color_conflicts == false then
		return
	end
	vim.api.nvim_buf_call(buf, function()
		if vim.b.css_color_pat == nil then
			vim.b.css_color_pat = vim.g.css_color_pat or ""
		end
		if vim.b.css_color_syn == nil then
			if vim.empty_dict then
				vim.b.css_color_syn = vim.empty_dict()
			else
				vim.b.css_color_syn = {}
			end
		end
		if vim.b.css_color_matches == nil then
			vim.b.css_color_matches = {}
		end
	end)
end

local function suppress_css_color(buf)
	if state.opts.suppress_css_color_conflicts == false then
		return
	end
	ensure_css_color_defaults(buf)
	vim.api.nvim_buf_call(buf, function()
		vim.b.css_color_disable = 1
		if vim.api.nvim_get_autocmds then
			local ok, autocmds = pcall(vim.api.nvim_get_autocmds, { buffer = buf })
			if ok then
				for _, ac in ipairs(autocmds) do
					if ac.event and css_color_events[ac.event] then
						local cmd = ac.command or ""
						local desc = (ac.desc or ""):lower()
						local group = (ac.group_name or ""):lower()
						if
							cmd:find("css_color", 1, true)
							or desc:find("css_color", 1, true)
							or group:find("css_color", 1, true)
						then
							pcall(vim.api.nvim_del_autocmd, ac.id)
						end
					end
				end
			end
		end
	end)
end

local function flush_queued_messages(fname)
	local key = buf_utils.canon(fname)
	local queued = state.queued_messages_by_file[key]
	if not queued or #queued == 0 then
		return
	end
	log.debug("Rendering queued messages for", fname)
	for _, msg in ipairs(queued) do
		log.debug("Rendering queued message", msg)
		render.render_message(msg)
	end
	state.queued_messages_by_file[key] = nil
end

local M = {}

function M.setup(opts)
	state.opts = vim.tbl_deep_extend("force", state.opts, opts or {})
	if state.opts.hover == false or type(state.opts.hover) ~= "table" then
		state.opts.hover = { enabled = false }
	else
		state.opts.hover.events = state.opts.hover.events or { "CursorHold" }
		state.opts.hover.hide_events = state.opts.hover.hide_events
			or { "CursorMoved", "CursorMovedI", "InsertEnter", "BufLeave" }
		state.opts.hover.border = state.opts.hover.border or "rounded"
		state.opts.hover.focusable = state.opts.hover.focusable ~= false and state.opts.hover.focusable or false
		state.opts.hover.relative = state.opts.hover.relative or "cursor"
		state.opts.hover.row = state.opts.hover.row ~= nil and state.opts.hover.row or 1
		state.opts.hover.col = state.opts.hover.col ~= nil and state.opts.hover.col or 0
	end
	if type(state.opts.popup_formatter) ~= "function" then
		state.opts.popup_formatter = require("console_inline.format").default
	end
	if vim.g.console_inline_lazy_setup_done then
		-- allow runtime restarts when autostart enabled
		if state.opts.autostart ~= false then
			server.start()
		end
		return
	end
	require("console_inline.commands")()
	-- Optional Tree-sitter integration (opt-in)
	if state.opts.use_treesitter then
		local ok_ts, ts_mod = pcall(require, "console_inline.treesitter")
		if ok_ts and ts_mod and type(ts_mod.activate) == "function" then
			local ok_activate, err = pcall(ts_mod.activate)
			if not ok_activate then
				log.debug("treesitter.activate failed", err)
			end
		else
			log.debug("treesitter module missing or activate not callable")
		end
	end
	if state.opts.autostart ~= false then
		vim.api.nvim_create_autocmd("VimEnter", {
			once = true,
			callback = function()
				server.start()
			end,
		})
	end

	-- On buffer read, optionally replay persisted logs and flush queued messages
	vim.api.nvim_create_autocmd("BufReadPost", {
		callback = function(args)
			local buf = args.buf
			local fname = vim.api.nvim_buf_get_name(buf)
			-- build index for faster lookups
			local ok_index, index = pcall(require, "console_inline.index")
			if ok_index then
				index.build(buf)
			end
			local logfile = vim.g.console_inline_log_path
				or os.getenv("CONSOLE_INLINE_LOG_PATH")
				or "console-inline.log"
			log.debug("BufReadPost", fname, "logfile=", logfile)
			suppress_css_color(buf)

			if state.opts.replay_persisted_logs ~= false then
				local buf_helpers = require("console_inline.buf")
				local canonical = buf_helpers.find_buf_by_path
				local buffer_path = canonical(fname)
				if buffer_path and buffer_path ~= "" then
					local matched = {}
					local file = io.open(logfile, "r")
					if file then
						for line in file:lines() do
							local ok, msg = pcall(vim.json.decode, line)
							if ok and type(msg) == "table" and msg.file and msg.line then
								if canonical(msg.file) == buffer_path then
									matched[#matched + 1] = msg
								end
							end
						end
						file:close()
					else
						log.debug("Could not open log file", logfile)
					end
					for _, msg in ipairs(matched) do
						log.debug("Rendering replayed log", msg)
						render.render_message(msg)
					end
				end
			else
				log.debug("Persisted log replay disabled")
			end

			flush_queued_messages(fname)
		end,
	})

	vim.api.nvim_create_autocmd("BufEnter", {
		callback = function()
			local buf = vim.api.nvim_get_current_buf()
			suppress_css_color(buf)
			local fname = vim.api.nvim_buf_get_name(0)
			if fname == "" then
				return
			end
			local ok_index, index = pcall(require, "console_inline.index")
			if ok_index and not (state.buffer_index and state.buffer_index[buf]) then
				index.build(buf)
			end
			flush_queued_messages(fname)
		end,
	})

	-- Track changes to keep index fresh (best-effort, not diffing deletions precisely)
	local change_group = vim.api.nvim_create_augroup("ConsoleInlineIndex", { clear = true })
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = change_group,
		callback = function(args)
			local buf = args.buf
			if not vim.api.nvim_buf_is_loaded(buf) then
				return
			end
			if state.opts.use_index == false then
				return
			end
			local ok_index, index = pcall(require, "console_inline.index")
			if not ok_index then
				return
			end
			-- naive approach: update a window of lines around cursor
			local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
			local changed = {}
			for ln = cursor_line - 2, cursor_line + 2 do
				if ln >= 0 and ln < vim.api.nvim_buf_line_count(buf) then
					changed[#changed + 1] = ln
				end
			end
			index.update_changed(buf, changed)
			index.handle_deletions(buf)
		end,
	})

	-- User command for manual reindex
	vim.api.nvim_create_user_command("ConsoleInlineReindex", function()
		if state.opts.use_index == false then
			vim.notify("console-inline: indexing disabled via opts.use_index", vim.log.levels.WARN)
			return
		end
	-- Benchmark command: synthetic candidate resolution performance
	vim.api.nvim_create_user_command("ConsoleInlineBenchmark", function(cmd_opts)
		local iterations = tonumber(cmd_opts.args) or 100
			local buf = vim.api.nvim_get_current_buf()
			if iterations <= 0 then
				iterations = 50
			end
			local total_ns = 0
			local max_ns = 0
			local min_ns = nil
			local render_mod = require("console_inline.render")
			local stats = state.benchmark_stats
			local line_count = vim.api.nvim_buf_line_count(buf)
			for i = 1, iterations do
				local line0 = math.random(0, math.max(0, line_count - 1))
				local fake_msg = {
					file = vim.api.nvim_buf_get_name(buf),
					line = line0 + 1,
					kind = "log",
					args = { "benchmark", "iter=" .. i, { id = i, tag = "bench" } },
					method = "log",
				}
				local before = vim.loop.hrtime()
				render_mod.render_message(fake_msg)
				local after = vim.loop.hrtime()
				local dt = after - before
				total_ns = total_ns + dt
				if dt > max_ns then
					max_ns = dt
				end
				if not min_ns or dt < min_ns then
					min_ns = dt
				end
			end
			local avg = total_ns / iterations
			local msg = string.format(
				"console-inline benchmark: iterations=%d avg=%.2fms min=%.2fms max=%.2fms index_used=%s scan_calls=%d index_calls=%d",
				iterations,
				avg / 1e6,
				(min_ns or 0) / 1e6,
				max_ns / 1e6,
				state.opts.use_index and "yes" or "no",
				stats.count_scan,
				stats.count_index
			)
			vim.notify(msg)
		end, { nargs = "?", desc = "Run console-inline placement benchmark (arg = iterations)" })

		-- Diagnostics command: show index & timing stats
		vim.api.nvim_create_user_command("ConsoleInlineDiagnostics", function()
			local buf = vim.api.nvim_get_current_buf()
			local idx = state.buffer_index and state.buffer_index[buf]
			local stats = state.benchmark_stats
			local line_count = vim.api.nvim_buf_line_count(buf)
			local console_lines = 0
			local token_count = 0
			local network_lines = 0
			if idx then
				for _, meta in pairs(idx.lines) do
					if meta.console then
						console_lines = console_lines + 1
					end
					if meta.network then
						network_lines = network_lines + 1
					end
					token_count = token_count + (#meta.tokens or 0)
				end
			end
			local avg_index = stats.count_index > 0 and (stats.total_index_time_ns / stats.count_index) or 0
			local avg_scan = stats.count_scan > 0 and (stats.total_scan_time_ns / stats.count_scan) or 0
			local recent = stats.entries[#stats.entries]
			local summary = {
				"console-inline diagnostics:",
				string.format("buffer lines=%d", line_count),
				string.format("index enabled=%s", tostring(state.opts.use_index)),
				string.format("indexed lines=%d", idx and vim.tbl_count(idx.lines) or 0),
				string.format("console lines indexed=%d", console_lines),
				string.format("network lines indexed=%d", network_lines),
				string.format("total tokens=%d", token_count),
				string.format("avg index candidate time=%.3fms", avg_index / 1e6),
				string.format("avg scan candidate time=%.3fms", avg_scan / 1e6),
				string.format("index calls=%d scan calls=%d", stats.count_index, stats.count_scan),
				string.format(
					"source map hits=%d misses=%d pending=%d",
					state.map_stats.hit,
					state.map_stats.miss,
					state.map_stats.pending
				),
			}
			if state.opts.use_treesitter then
				local ok_ts, ts_mod = pcall(require, "console_inline.treesitter")
				if ok_ts and ts_mod and ts_mod.cache then
					local cache = ts_mod.cache[buf]
					if cache then
						local ctx_count = 0
						for _ in pairs(cache.ctx or {}) do
							ctx_count = ctx_count + 1
						end
						summary[#summary + 1] = string.format(
							"treesitter active=true lang=%s ctx_lines=%d",
							cache.lang or "unknown",
							ctx_count
						)
					else
						summary[#summary + 1] = "treesitter active=true (no cache for buffer yet)"
					end
				else
					summary[#summary + 1] = "treesitter active=true (module/capture unavailable)"
				end
			else
				summary[#summary + 1] = "treesitter active=false"
			end
			if recent then
				summary[#summary + 1] = string.format(
					"last placement: candidates=%d time=%.3fms base=%d resolved=%d",
					recent.candidate_count,
					recent.time_ns / 1e6,
					recent.base,
					recent.resolved
				)
			end
			vim.notify(table.concat(summary, "\n"))
		end, { desc = "Show console-inline index & timing diagnostics" })
		local buf = vim.api.nvim_get_current_buf()
		local ok_index, index = pcall(require, "console_inline.index")
		if not ok_index then
			vim.notify("console-inline: index module missing", vim.log.levels.ERROR)
			return
		end
		index.build(buf)
		vim.notify("console-inline: buffer reindexed")
	end, { desc = "Rebuild console-inline buffer index" })

	local hover_opts = state.opts.hover or {}
	if hover_opts.enabled ~= false then
		local hover_group = vim.api.nvim_create_augroup("ConsoleInlineHover", { clear = true })
		local events = hover_opts.events or { "CursorHold" }
		if type(events) == "string" then
			events = { events }
		end
		local hide_events = hover_opts.hide_events or { "CursorMoved", "CursorMovedI", "InsertEnter", "BufLeave" }
		if type(hide_events) == "string" then
			hide_events = { hide_events }
		end
		vim.api.nvim_create_autocmd(events, {
			group = hover_group,
			callback = function()
				render.maybe_show_hover()
			end,
		})
		vim.api.nvim_create_autocmd(hide_events, {
			group = hover_group,
			callback = function()
				render.close_hover_popup()
			end,
		})
	end
	vim.g.console_inline_lazy_setup_done = true
end

function M.start(...)
	return server.start(...)
end
function M.stop(...)
	return server.stop(...)
end
function M.toggle(...)
	return server.toggle(...)
end

return M
