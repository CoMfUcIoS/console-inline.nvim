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
	},
	extmarks_by_buf_line = {},
	last_msg_by_buf_line = {},
    queued_messages_by_file = {},
}

return M
