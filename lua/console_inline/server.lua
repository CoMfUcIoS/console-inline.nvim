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

local uv = vim.loop
local state = require("console_inline.state")
local render = require("console_inline.render")
local relay = require("console_inline.relay")

local M = {}

-- Start TCP server for a session (or global if session_id nil)
local function start_tcp(opts, session_state)
	if session_state.server then
		return
	end

	local server = uv.new_tcp()
	server:bind(opts.host, opts.port)
	server:listen(128, function(err)
		assert(not err, err)
		local sock = uv.new_tcp()
		server:accept(sock)
		table.insert(session_state.sockets, sock)
		local buf = ""
		sock:read_start(function(e, chunk)
			if e then
				return
			end
			if not chunk then
				return
			end
			buf = buf .. chunk
			while true do
				local i = buf:find("\n", 1, true)
				if not i then
					break
				end
				local line = buf:sub(1, i - 1)
				buf = buf:sub(i + 1)
				local ok, msg = pcall(vim.json.decode, line)
				if ok and type(msg) == "table" then
					vim.schedule(function()
						render.render_message(msg)
					end)
				end
			end
		end)
	end)

	session_state.server = server
end

-- Start server (backwards compatible, single-session by default)
function M.start(session_id)
	local sess_state = state.get_session_state(session_id)

	if sess_state.running then
		return
	end

	local opts = state.opts
	if session_id and state.opts.sessions_enabled then
		local sessions = require("console_inline.sessions")
		local session = sessions.get(session_id)
		if not session then
			vim.notify("Session not found: " .. session_id)
			return
		end
		opts = sessions.get_merged_config(session_id, state.opts)
	end

	start_tcp(opts, sess_state)
	sess_state.running = true
	relay.ensure()
	vim.notify(string.format("console-inline: listening on %s:%d", opts.host, opts.port))
end

-- Stop server (backwards compatible, single-session by default)
function M.stop(session_id)
	local sess_state = state.get_session_state(session_id)

	if not sess_state.running then
		return
	end

	sess_state.running = false
	if sess_state.server then
		pcall(sess_state.server.close, sess_state.server)
		sess_state.server = nil
	end
	for _, s in ipairs(sess_state.sockets) do
		pcall(s.close, s)
	end
	sess_state.sockets = {}

	-- Only stop relay if no other sessions are running
	if state.opts.sessions_enabled then
		local sessions = require("console_inline.sessions")
		local any_running = false
		for _, session in pairs(sessions.sessions) do
			local s = state.sessions_state[session.id]
			if s and s.running then
				any_running = true
				break
			end
		end
		if not any_running then
			relay.stop()
		end
	else
		relay.stop()
	end

	vim.notify("console-inline: stopped")
end

-- Toggle server (backwards compatible)
function M.toggle(session_id)
	local sess_state = state.get_session_state(session_id)
	if sess_state.running then
		M.stop(session_id)
	else
		M.start(session_id)
	end
end

-- Backwards compatibility aliases
function M.start_for_session(session_id)
	return M.start(session_id)
end

function M.stop_for_session(session_id)
	return M.stop(session_id)
end

return M
