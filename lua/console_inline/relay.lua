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
local log = require("console_inline.log")

local M = {}

local function relay_script_path()
	if state.relay_script_path then
		return state.relay_script_path
	end
	local info = debug.getinfo(1, "S")
	local source = info and info.source or ""
	if vim.startswith(source, "@") then
		source = source:sub(2)
	end
	local dir = vim.fn.fnamemodify(source, ":p:h")
	local root = vim.fn.fnamemodify(dir .. "/../..", ":p")
	local script = vim.fn.fnamemodify(root .. "/relay/auto-relay.cjs", ":p")
	state.relay_script_path = script
	return script
end

local function close_handle()
	if state.relay_handle then
		pcall(state.relay_handle.close, state.relay_handle)
		state.relay_handle = nil
	end
	if state.relay_stderr then
		pcall(state.relay_stderr.close, state.relay_stderr)
		state.relay_stderr = nil
	end
	state.relay_pid = nil
end

local function handle_exit(code, signal)
	log.debug("relay exited", code, signal)
	close_handle()
	if state.running and state.opts.autostart_relay ~= false then
		vim.defer_fn(function()
			M.start()
		end, 1000)
	end
end

function M.start()
	if state.relay_handle then
		return true
	end
	if state.opts.autostart_relay == false then
		return false
	end

	if vim.fn.executable("node") == 0 then
		log.debug("relay: node executable not found")
		return false
	end

	local script = relay_script_path()
	if script == "" or vim.fn.filereadable(script) == 0 then
		log.debug("relay script missing", script .. ". run :ConsoleInlineRelayBuild or npm run build:relay")
		return false
	end

	local stderr_pipe = uv.new_pipe(false)
	state.relay_stderr = stderr_pipe

	local handle, pid = uv.spawn("node", {
		args = { script },
		stdio = { nil, nil, stderr_pipe },
	}, handle_exit)

	if not handle then
		log.debug("failed to spawn relay", pid)
		if stderr_pipe then
			stderr_pipe:close()
			state.relay_stderr = nil
		end
		return false
	end

	state.relay_handle = handle
	state.relay_pid = pid

	if stderr_pipe then
		stderr_pipe:read_start(function(err, data)
			if err then
				log.debug("relay stderr error", err)
			elseif data then
				log.debug("relay", data)
			end
		end)
	end
	log.debug("relay started", pid)
	return true
end

function M.stop()
	if state.relay_handle then
		log.debug("stopping relay")
		pcall(state.relay_handle.kill, state.relay_handle)
	end
	close_handle()
end

function M.ensure()
	if state.opts.autostart_relay == false then
		return false
	end
	return M.start()
end

return M
