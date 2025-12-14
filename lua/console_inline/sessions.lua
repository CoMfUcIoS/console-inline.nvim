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
Multi-workspace session management for console-inline.nvim

Enables running multiple independent server instances, each bound to a different
port and root directory. Sessions can be created, switched, persisted across restarts.

Session Structure:
  {
    id = "unique-session-id",
    root = "/path/to/project",
    port = 36123,
    active = true,
    created_at = timestamp,
    last_used = timestamp,
    config_overrides = { ... } -- per-session opts
    state = {
      server = uv_tcp_handle,
      sockets = { ... },
      running = boolean,
    }
  }
]]

local M = {}

-- Session storage: id -> session
M.sessions = {}

-- Current active session ID
M.current_session_id = nil

-- Next available port (auto-incremented)
M.next_port = 36124

-- Sessions data directory
local function get_data_dir()
	local data_dir = vim.fn.stdpath("data") .. "/console_inline_sessions"
	vim.fn.mkdir(data_dir, "p")
	return data_dir
end

-- Generate unique session ID from root directory
local function generate_session_id(root)
	-- Use hash of root path to create consistent session ID
	return vim.fn.fnamemodify(root, ":t") .. "_" .. math.floor(vim.fn.localtime() * 1000) % 100000
end

-- Get project root (git/hg/lsp root or cwd)
local function get_project_root()
	local root = vim.fn.getcwd()
	-- Try to find git root
	local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
	if vim.v.shell_error == 0 and git_root ~= "" then
		root = git_root
	end
	return root
end

-- Allocate next available port
local function allocate_port()
	local port = M.next_port
	M.next_port = M.next_port + 1
	return port
end

-- Check if session is running
local function session_is_running(session)
	return session and session.state and session.state.running or false
end

-- Create a new session
function M.create(root, port, config_overrides)
	root = root or get_project_root()
	port = port or allocate_port()

	-- Check if session for this root already exists
	for _, session in pairs(M.sessions) do
		if session.root == root then
			return nil, "Session already exists for " .. root
		end
	end

	local session_id = generate_session_id(root)
	local session = {
		id = session_id,
		root = root,
		port = port,
		active = false,
		created_at = vim.fn.localtime(),
		last_used = vim.fn.localtime(),
		config_overrides = config_overrides or {},
		state = {
			server = nil,
			sockets = {},
			running = false,
		},
	}

	M.sessions[session_id] = session
	return session_id
end

-- Get session by ID
function M.get(session_id)
	return M.sessions[session_id]
end

-- Get session by root directory
function M.get_by_root(root)
	for _, session in pairs(M.sessions) do
		if session.root == root then
			return session
		end
	end
	return nil
end

-- Get all sessions
function M.list()
	local sessions = {}
	for _, session in pairs(M.sessions) do
		table.insert(sessions, session)
	end
	-- Sort by last_used (most recent first)
	table.sort(sessions, function(a, b)
		return a.last_used > b.last_used
	end)
	return sessions
end

-- Switch to a session (makes it active)
function M.switch(session_id)
	local session = M.get(session_id)
	if not session then
		return false, "Session not found: " .. session_id
	end

	-- Mark previous session as inactive
	if M.current_session_id then
		local prev = M.get(M.current_session_id)
		if prev then
			prev.active = false
		end
	end

	-- Mark new session as active
	session.active = true
	session.last_used = vim.fn.localtime()
	M.current_session_id = session_id

	return true
end

-- Get current active session
function M.current()
	if M.current_session_id then
		return M.get(M.current_session_id)
	end
	return nil
end

-- Delete a session
function M.delete(session_id)
	local session = M.get(session_id)
	if not session then
		return false, "Session not found: " .. session_id
	end

	-- Stop server if running
	if session_is_running(session) then
		require("console_inline.server").stop_for_session(session_id)
	end

	-- Remove from current if active
	if M.current_session_id == session_id then
		M.current_session_id = nil
	end

	-- Delete persisted data
	local data_dir = get_data_dir()
	local session_file = data_dir .. "/" .. session_id .. ".json"
	if vim.fn.filereadable(session_file) == 1 then
		vim.fn.delete(session_file)
	end

	M.sessions[session_id] = nil
	return true
end

-- Update session config overrides
function M.set_config(session_id, config_overrides)
	local session = M.get(session_id)
	if not session then
		return false, "Session not found: " .. session_id
	end

	session.config_overrides = vim.tbl_deep_extend("force", session.config_overrides, config_overrides)
	return true
end

-- Get merged config for a session (base opts + overrides)
function M.get_merged_config(session_id, base_opts)
	local session = M.get(session_id)
	if not session then
		return base_opts
	end

	return vim.tbl_deep_extend("force", base_opts, {
		port = session.port,
	}, session.config_overrides)
end

-- Save all sessions to disk
function M.persist()
	local data_dir = get_data_dir()
	for session_id, session in pairs(M.sessions) do
		-- Don't persist server state, only metadata
		local persist_data = {
			id = session.id,
			root = session.root,
			port = session.port,
			active = session.active,
			created_at = session.created_at,
			last_used = session.last_used,
			config_overrides = session.config_overrides,
		}

		local session_file = data_dir .. "/" .. session_id .. ".json"
		local ok, encoded = pcall(vim.json.encode, persist_data)
		if ok then
			local file = io.open(session_file, "w")
			if file then
				file:write(encoded)
				file:close()
			end
		end
	end
end

-- Load sessions from disk
function M.load_persisted()
	local data_dir = get_data_dir()
	if vim.fn.isdirectory(data_dir) == 0 then
		return
	end

	local files = vim.fn.glob(data_dir .. "/*.json", false, true)
	for _, file in ipairs(files) do
		local ok, content = pcall(function()
			local f = io.open(file, "r")
			if f then
				local data = f:read("*a")
				f:close()
				return data
			end
		end)

		if ok and content then
			local decoded = vim.json.decode(content)
			if decoded then
				-- Restore session (without server state)
				M.sessions[decoded.id] = {
					id = decoded.id,
					root = decoded.root,
					port = decoded.port,
					active = false, -- reset active on load
					created_at = decoded.created_at,
					last_used = decoded.last_used,
					config_overrides = decoded.config_overrides or {},
					state = {
						server = nil,
						sockets = {},
						running = false,
					},
				}
			end
		end
	end
end

-- Get formatted session info for display
function M.format_session(session)
	local status = session_is_running(session) and "✓ running" or "✗ stopped"
	local socket_count = #(session.state.sockets or {})
	local last_used = os.difftime(vim.fn.localtime(), session.last_used)
	local last_used_str = last_used < 60 and (last_used .. "s ago")
		or last_used < 3600 and (math.floor(last_used / 60) .. "m ago")
		or (math.floor(last_used / 3600) .. "h ago")

	return string.format(
		"%s | %s:%d | %d sockets | %s",
		status,
		vim.fn.fnamemodify(session.root, ":~"),
		session.port,
		socket_count,
		last_used_str
	)
end

-- Clean up: ensure auto-loaded sessions don't accumulate
function M.cleanup_stale_sessions(max_age_days)
	max_age_days = max_age_days or 30
	local cutoff_time = vim.fn.localtime() - (max_age_days * 86400)

	for session_id, session in pairs(M.sessions) do
		if session.last_used < cutoff_time and not session_is_running(session) then
			M.delete(session_id)
		end
	end
end

return M
