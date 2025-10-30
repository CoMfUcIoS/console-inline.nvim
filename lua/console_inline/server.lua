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

local function start_tcp()
	if state.server then
		return
	end
	local server = uv.new_tcp()
	server:bind(state.opts.host, state.opts.port)
	server:listen(128, function(err)
		assert(not err, err)
		local sock = uv.new_tcp()
		server:accept(sock)
		table.insert(state.sockets, sock)
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
	state.server = server
end

function M.start()
	if state.running then
		return
	end
	start_tcp()
	state.running = true
	relay.ensure()
	vim.notify(string.format("console-inline: listening on %s:%d", state.opts.host, state.opts.port))
end

function M.stop()
	if not state.running then
		return
	end
	state.running = false
	if state.server then
		pcall(state.server.close, state.server)
		state.server = nil
	end
	for _, s in ipairs(state.sockets) do
		pcall(s.close, s)
	end
	state.sockets = {}
	relay.stop()
	vim.notify("console-inline: stopped")
end

function M.toggle()
	if state.running then
		M.stop()
	else
		M.start()
	end
end

return M
