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
	},
	extmarks_by_buf_line = {},
	last_msg_by_buf_line = {},
	queued_messages_by_file = {},
	relay_handle = nil,
	relay_stderr = nil,
	relay_pid = nil,
}

return M
