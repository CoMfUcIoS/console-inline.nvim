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
			flush_queued_messages(fname)
		end,
	})

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
