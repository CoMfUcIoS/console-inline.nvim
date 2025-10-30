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

local M = {
	ns = vim.api.nvim_create_namespace("console_inline"),
	server = nil,
	sockets = {},
	running = false,
	opts = {
		host = "127.0.0.1",
		port = 36123,
		open_missing_files = false,
		severity_filter = { log = true, info = true, warn = true, error = true },
		throttle_ms = 30,
		max_len = 160,
		autostart = true,
		autostart_relay = true,
		replay_persisted_logs = false,
		suppress_css_color_conflicts = true,
		popup_formatter = nil,
		history_size = 200,
		pattern_overrides = nil,
		filters = nil,
		hover = {
			enabled = true,
			events = { "CursorHold" },
			hide_events = { "CursorMoved", "CursorMovedI", "InsertEnter", "BufLeave" },
			border = "rounded",
			focusable = false,
			relative = "cursor",
			row = 1,
			col = 0,
		},
	},
	extmarks_by_buf_line = {},
	last_msg_by_buf_line = {},
	queued_messages_by_file = {},
	relay_handle = nil,
	relay_stderr = nil,
	relay_pid = nil,
	history = {},
	hover_popup = nil,
}

return M
