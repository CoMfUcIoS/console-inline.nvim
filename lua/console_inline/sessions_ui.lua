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

--[[
Interactive UI for multi-workspace session management.

Displays active sessions with status, allows switching between them,
starting/stopping individual sessions, and managing configuration.
]]

local M = {}

local state = require("console_inline.state")
local sessions = require("console_inline.sessions")
local server = require("console_inline.server")

local session_buf = nil
local session_win = nil
local session_lines = {} -- Map line number -> session_id for navigation

-- Render session list to buffer
local function render_sessions()
	if not session_buf or not vim.api.nvim_buf_is_valid(session_buf) then
		return
	end

	session_lines = {}
	local lines = {
		"┌─ Console Inline Sessions ─────────────────────────────────────┐",
		"│ <CR> switch | <Space> toggle | <Del> delete | <q> close      │",
		"├────────────────────────────────────────────────────────────────┤",
	}

	local session_list = sessions.list()

	if #session_list == 0 then
		table.insert(lines, "│ No sessions. Create one with :ConsoleInlineSessionNew <root>    │")
	else
		for i, session in ipairs(session_list) do
			local formatted = sessions.format_session(session)
			local is_current = sessions.current_session_id == session.id and "→" or " "
			local display = string.format("│ %s [%d] %s", is_current, i, formatted)

			-- Pad to width
			while #display < 66 do
				display = display .. " "
			end
			display = display .. "│"

			table.insert(lines, display)
			session_lines[#lines] = session.id
		end
	end

	table.insert(lines, "└────────────────────────────────────────────────────────────────┘")

	vim.api.nvim_buf_set_lines(session_buf, 0, -1, false, lines)
end

-- Open session manager UI
function M.open()
	-- Create buffer if not exists
	if not session_buf or not vim.api.nvim_buf_is_valid(session_buf) then
		session_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(session_buf, "ConsoleInlineSessions")

		-- Set buffer options
		vim.api.nvim_set_option_value("buftype", "nofile", { buf = session_buf })
		vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = session_buf })
		vim.api.nvim_set_option_value("modifiable", true, { buf = session_buf })

		-- Set keymaps
		local opts = { noremap = true, silent = true, buffer = session_buf }

		-- Switch to session
		vim.keymap.set("n", "<CR>", function()
			local lnum = vim.api.nvim_win_get_cursor(session_win)[1]
			local session_id = session_lines[lnum]
			if session_id then
				sessions.switch(session_id)
				render_sessions()
				vim.notify("Switched to session: " .. session_id, vim.log.levels.INFO)
			end
		end, opts)

		-- Toggle session (start/stop)
		vim.keymap.set("n", "<Space>", function()
			local lnum = vim.api.nvim_win_get_cursor(session_win)[1]
			local session_id = session_lines[lnum]
			if session_id then
				local sess = sessions.get(session_id)
				if sess then
					if sess.state.running then
						server.stop_for_session(session_id)
						vim.notify("Session stopped: " .. session_id, vim.log.levels.INFO)
					else
						server.start_for_session(session_id)
						vim.notify("Session started: " .. session_id, vim.log.levels.INFO)
					end
					render_sessions()
				end
			end
		end, opts)

		-- Delete session
		vim.keymap.set("n", "<Del>", function()
			local lnum = vim.api.nvim_win_get_cursor(session_win)[1]
			local session_id = session_lines[lnum]
			if session_id then
				local choice = vim.fn.confirm("Delete session: " .. session_id .. "?", "&Yes\n&No", 2)
				if choice == 1 then
					sessions.delete(session_id)
					render_sessions()
					vim.notify("Session deleted: " .. session_id, vim.log.levels.INFO)
				end
			end
		end, opts)

		-- Close
		vim.keymap.set("n", "q", function()
			M.close()
		end, opts)

		vim.keymap.set("n", "<Esc>", function()
			M.close()
		end, opts)
	end

	-- Create floating window if not exists
	if not session_win or not vim.api.nvim_win_is_valid(session_win) then
		session_win = vim.api.nvim_open_win(session_buf, true, {
			relative = "editor",
			width = 70,
			height = 15,
			row = math.floor((vim.o.lines - 15) / 2),
			col = math.floor((vim.o.columns - 70) / 2),
			border = "rounded",
			title = " Console Inline Sessions ",
			title_pos = "center",
		})

		vim.api.nvim_set_option_value("winhl", "Normal:Normal", { win = session_win })
	end

	render_sessions()
	vim.api.nvim_set_option_value("modifiable", false, { buf = session_buf })
end

-- Close session manager UI
function M.close()
	if session_win and vim.api.nvim_win_is_valid(session_win) then
		vim.api.nvim_win_close(session_win, true)
		session_win = nil
	end
	sessions.persist()
end

return M
