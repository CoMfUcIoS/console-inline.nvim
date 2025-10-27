local state = require("console_inline.state")
local server = require("console_inline.server")

local M = {}

function M.setup(opts)
	if vim.g.console_inline_lazy_setup_done then
		return
	end
	state.opts = vim.tbl_deep_extend("force", state.opts, opts or {})
	require("console_inline.commands")()
	vim.api.nvim_create_autocmd("VimEnter", {
		once = true,
		callback = function()
			server.start()
		end,
	})

    -- On buffer read, show persistent logs and queued messages
    vim.api.nvim_create_autocmd("BufReadPost", {
        callback = function(args)
            local buf = args.buf
            local fname = vim.api.nvim_buf_get_name(buf)
            local logs = {}
            local logfile = "console-inline.log"
            local f = io.open(logfile, "r")
            if f then
                for line in f:lines() do
                    local ok, msg = pcall(vim.json.decode, line)
                    if ok and type(msg) == "table" and msg.file and msg.line then
                        -- Normalize file path
                        local canon = require("console_inline.buf").find_buf_by_path
                        local buf_match = canon(msg.file)
                        local fname_match = canon(fname)
                        if buf_match == fname_match then
                            table.insert(logs, msg)
                        end
                    end
                end
                f:close()
            end
            local render = require("console_inline.render")
            for _, msg in ipairs(logs) do
                render.render_message(msg)
            end
            -- Render queued messages for this file
            local state = require("console_inline.state")
            local queued = state.queued_messages_by_file[fname]
            if queued then
                for _, msg in ipairs(queued) do
                    render.render_message(msg)
                end
                state.queued_messages_by_file[fname] = nil
            end
        end
    })
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
