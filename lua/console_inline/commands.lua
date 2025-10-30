local server = require("console_inline.server")
local render = require("console_inline.render")
local history = require("console_inline.history")

return function()
	local state = require("console_inline.state")

	vim.api.nvim_create_user_command("ConsoleInlineStatus", function()
		local running = state.running and "running" or "stopped"
		local host = state.opts.host or "127.0.0.1"
		local port = state.opts.port or 36123
		local sockets = state.sockets and #state.sockets or 0
		vim.notify(
			string.format("console-inline: TCP server is %s on %s:%d (%d active sockets)", running, host, port, sockets)
		)
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
end
