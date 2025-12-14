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

local server = require("console_inline.server")
local render = require("console_inline.render")
local history = require("console_inline.history")
local runner = require("console_inline.runner")
local inspector = require("console_inline.inspector")

return function()
	local state = require("console_inline.state")

	vim.api.nvim_create_user_command("ConsoleInlineStatus", function()
		local running = state.running and "✓ running" or "✗ stopped"
		local host = state.opts.host or "127.0.0.1"
		local port = state.opts.port or 36123
		local sockets = state.sockets and #state.sockets or 0
		
		-- Message count per buffer
		local message_stats = {}
		local total_messages = 0
		local severity_count = { log = 0, info = 0, warn = 0, error = 0 }
		for bufnr, lines_map in pairs(state.extmarks_by_buf_line) do
			local count = 0
			for _, extmark_id in pairs(lines_map) do
				if type(extmark_id) == "number" then
					count = count + 1
				end
			end
			if count > 0 then
				message_stats[bufnr] = count
				total_messages = total_messages + count
			end
		end
		
		-- Count by severity from history
		for _, entry in ipairs(state.history) do
			local kind = entry.kind or "log"
			severity_count[kind] = (severity_count[kind] or 0) + 1
		end
		
		-- Source map stats
		local map_hit = state.map_stats.hit or 0
		local map_miss = state.map_stats.miss or 0
		local map_pending = state.map_stats.pending or 0
		local map_total = map_hit + map_miss + (map_pending > 0 and 1 or 0)
		local map_rate = map_total > 0 and string.format("%.1f%%", (map_hit / map_total) * 100) or "N/A"
		
		-- Active filters
		local filters = state.opts.filters
		local filter_status = "none"
		if type(filters) == "table" then
			local has_allow = type(filters.allow) == "table"
			local has_deny = type(filters.deny) == "table"
			local has_severity = type(filters.severity) == "table" and #filters.severity > 0
			if has_allow or has_deny or has_severity then
				filter_status = string.format("%s%s%s",
					has_allow and "allow " or "",
					has_deny and "deny " or "",
					has_severity and "severity" or ""
				):gsub("%s+$", "")
			end
		end
		
		-- Last message timestamp
		local last_msg_time = state.history and #state.history > 0 and state.history[#state.history].timestamp or nil
		local time_str = "never"
		if last_msg_time then
			local elapsed = os.time() - (tonumber(last_msg_time) or 0)
			if elapsed < 60 then
				time_str = string.format("%ds ago", elapsed)
			elseif elapsed < 3600 then
				time_str = string.format("%dm ago", math.floor(elapsed / 60))
			else
				time_str = string.format("%dh ago", math.floor(elapsed / 3600))
			end
		end
		
		-- Build status message
		local lines = {
			string.format("━━━━━━━━━━━ Console Inline Status ━━━━━━━━━━━"),
			string.format("Server: %s on %s:%d", running, host, port),
			string.format("Sockets: %d active", sockets),
			"",
			string.format("Messages: %d total [log:%d info:%d warn:%d error:%d]",
				total_messages, severity_count.log, severity_count.info, severity_count.warn, severity_count.error),
			string.format("Source Maps: %d hits, %d misses (%s resolution rate)", map_hit, map_miss, map_rate),
			string.format("Filters: %s", filter_status),
			string.format("Last message: %s", time_str),
			"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
		}
		
		vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
	end, {})
	vim.api.nvim_create_user_command("ConsoleInlineToggle", function()
		server.toggle()
	end, {})

	vim.api.nvim_create_user_command("ConsoleInlineClear", function()
		render.clear_current_buffer()
	end, {})

	vim.api.nvim_create_user_command("ConsoleInlineCopy", function()
		render.copy_current_line()
	end, {})

	vim.api.nvim_create_user_command("ConsoleInlinePopup", function()
		local entry = render.get_entry_at_cursor()
		if not entry then
			vim.notify("console-inline: no message at cursor", vim.log.levels.WARN)
			return
		end
		local popup = render.open_standalone_popup(entry)
		if not popup then
			vim.notify("console-inline: failed to open popup", vim.log.levels.ERROR)
		end
	end, {})

	vim.api.nvim_create_user_command("ConsoleInlineHistory", function()
		if history.is_empty() then
			vim.notify("console-inline: history is empty", vim.log.levels.WARN)
			return
		end
		local ok, _ = pcall(require, "telescope")
		if not ok then
			vim.notify("console-inline: telescope.nvim is required for history", vim.log.levels.ERROR)
			return
		end
		local pickers = require("telescope.pickers")
		local finders = require("telescope.finders")
		local conf = require("telescope.config").values
		local previewers = require("telescope.previewers")
		local actions_state = require("telescope.actions.state")
		local actions = require("telescope.actions")
		local formatter = state.opts.popup_formatter or require("console_inline.format").default
		local entries = history.entries()
		local previewer = previewers.new_buffer_previewer({
			define_preview = function(self, selection)
				local value = selection.value
				local lines
				if value then
					local ok_fmt, result = pcall(formatter, value)
					if ok_fmt and type(result) == "table" and #result > 0 then
						lines = {}
						for _, line in ipairs(result) do
							lines[#lines + 1] = tostring(line)
						end
					else
						lines = vim.split(value.payload or value.display or "", "\n", true)
					end
				else
					lines = { "<no entry>" }
				end
				if value and type(value.trace) == "table" and #value.trace > 0 then
					lines = lines or {}
					for idx, frame in ipairs(value.trace) do
						lines[#lines + 1] = string.format("[trace %d] %s", idx, tostring(frame))
					end
				end
				if value and type(value.time) == "table" and value.time.label then
					local timer = value.time
					local label = timer.label or "timer"
					local timer_entry
					if timer.duration_ms then
						timer_entry = string.format("[time] %s: %.3f ms", label, tonumber(timer.duration_ms) or 0)
					elseif timer.missing then
						timer_entry = string.format("[time] Timer '%s' not found", label)
					else
						timer_entry = string.format("[time] %s", label)
					end
					lines[#lines + 1] = timer_entry
				end
				if #lines == 0 then
					lines = { "<empty>" }
				end
				vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
			end,
		})
		pickers
			.new({}, {
				prompt_title = "Console Inline History",
				finder = finders.new_table({
					results = entries,
					entry_maker = function(item)
						local file = item.file or ""
						local short = file ~= "" and vim.fn.fnamemodify(file, ":~:.") or "<unknown>"
						local line = tonumber(item.render_line or item.original_line or item.line) or 1
						local base = item.display or item.display_payload or item.payload or ""
						local severity = item.kind and item.kind:upper() or ""
						local icon = item.icon or ""
						local prefix = icon ~= "" and (icon .. " ")
							or (severity ~= "" and ("[" .. severity .. "] ") or "")
						local display = string.format("%s:%d %s%s", short, line, prefix, base)
						local ordinal = table.concat({ short, tostring(line), severity, base }, " ")
						return {
							value = item,
							display = display,
							ordinal = ordinal,
						}
					end,
				}),
				sorter = conf.generic_sorter({}),
				previewer = previewer,
				attach_mappings = function(prompt_bufnr, map)
					actions.select_default:replace(function()
						local selection = actions_state.get_selected_entry()
						actions.close(prompt_bufnr)
						if not selection or not selection.value then
							return
						end
						local item = selection.value
						if not item.file or item.file == "" then
							return
						end
						local ok_edit, err = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(item.file))
						if not ok_edit then
							vim.notify(
								string.format("console-inline: failed to open %s (%s)", item.file, err),
								vim.log.levels.ERROR
							)
							return
						end
						local target_line = tonumber(item.render_line or item.original_line or item.line) or 1
						vim.api.nvim_win_set_cursor(0, { math.max(1, target_line), 0 })
					end)
					map({ "i", "n" }, "<C-d>", function()
						history.clear()
						local picker = actions_state.get_current_picker(prompt_bufnr)
						picker:refresh(finders.new_table({ results = history.entries() }), {})
					end)
					return true
				end,
			})
			:find()
	end, {})

	vim.api.nvim_create_user_command("ConsoleInlineNext", function()
		local bufnr = vim.api.nvim_get_current_buf()
		local cursor_pos = vim.api.nvim_win_get_cursor(0)
		local lnum = cursor_pos[1] - 1 -- Convert to 0-indexed
		
		local entry = history.next_per_line(bufnr, lnum)
		if not entry then
			vim.notify("console-inline: no message to cycle to", vim.log.levels.WARN)
			return
		end
		
		-- Re-render the line with updated entry
		render.refresh_line_text(bufnr, lnum, entry)
		
		local current, total = history.get_position_per_line(bufnr, lnum)
		if current and total then
			vim.notify(string.format("console-inline: message [%d/%d]", current, total), vim.log.levels.INFO)
		end
	end, {})

	vim.api.nvim_create_user_command("ConsoleInlinePrev", function()
		local bufnr = vim.api.nvim_get_current_buf()
		local cursor_pos = vim.api.nvim_win_get_cursor(0)
		local lnum = cursor_pos[1] - 1 -- Convert to 0-indexed
		
		local entry = history.prev_per_line(bufnr, lnum)
		if not entry then
			vim.notify("console-inline: no message to cycle to", vim.log.levels.WARN)
			return
		end
		
		-- Re-render the line with updated entry
		render.refresh_line_text(bufnr, lnum, entry)
		
		local current, total = history.get_position_per_line(bufnr, lnum)
		if current and total then
			vim.notify(string.format("console-inline: message [%d/%d]", current, total), vim.log.levels.INFO)
		end
	end, {})

	vim.api.nvim_create_user_command("ConsoleInlineRun", function(opts)
		local runtime = opts.args and opts.args ~= "" and opts.args or nil
		local file = vim.api.nvim_buf_get_name(0)
		
		if file == "" or file == nil then
			vim.notify("console-inline: no file in current buffer", vim.log.levels.WARN)
			return
		end
		
		local ok, err = runner.run(file, runtime)
		if not ok then
			vim.notify("console-inline: " .. err, vim.log.levels.ERROR)
		end
	end, { nargs = "?" })

	vim.api.nvim_create_user_command("ConsoleInlineInspector", function()
		inspector.open()
	end, {})
end
