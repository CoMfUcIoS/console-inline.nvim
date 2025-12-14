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

local state = require("console_inline.state")
local M = {}

-- Detect runtime from file or environment
local function detect_runtime(file)
	local cwd = vim.fn.fnamemodify(file, ":p:h")

	-- Check for deno.json in parent directories
	local current = cwd
	for _ = 1, 10 do
		if vim.fn.filereadable(current .. "/deno.json") == 1 then
			return "deno"
		end
		if vim.fn.filereadable(current .. "/deno.jsonc") == 1 then
			return "deno"
		end
		current = vim.fn.fnamemodify(current, ":h")
		if current == vim.fn.fnamemodify(current, ":h") then
			break
		end
	end

	-- Check for bun.lockb
	current = cwd
	for _ = 1, 10 do
		if vim.fn.filereadable(current .. "/bun.lockb") == 1 then
			return "bun"
		end
		current = vim.fn.fnamemodify(current, ":h")
		if current == vim.fn.fnamemodify(current, ":h") then
			break
		end
	end

	-- Check for package.json to determine package manager
	current = cwd
	for _ = 1, 10 do
		if vim.fn.filereadable(current .. "/package.json") == 1 then
			local file_handle = io.open(current .. "/package.json", "r")
			if file_handle then
				local content = file_handle:read("*a")
				file_handle:close()
				-- Simple heuristic: check for "packageManager" field or lock files
				if content:find("yarn") then
					return "node"
				end
				if content:find("pnpm") then
					return "node"
				end
			end
			return "node"
		end
		current = vim.fn.fnamemodify(current, ":h")
		if current == vim.fn.fnamemodify(current, ":h") then
			break
		end
	end

	return "node"
end

-- Get shim path for the specified runtime
local function get_shim_path(runtime)
	local info = debug.getinfo(1, "S")
	local source = info and info.source or ""
	if vim.startswith(source, "@") then
		source = source:sub(2)
	end
	local dir = vim.fn.fnamemodify(source, ":p:h")
	local root = vim.fn.fnamemodify(dir .. "/../..", ":p")

	if runtime == "deno" then
		return vim.fn.fnamemodify(root .. "/shim/deno/console-inline-shim.ts", ":p")
	elseif runtime == "bun" then
		return vim.fn.fnamemodify(root .. "/shim/bun/console-inline-shim.ts", ":p")
	else
		return vim.fn.fnamemodify(root .. "/shim/node/console-inline-shim.cjs", ":p")
	end
end

-- Execute file with the given runtime
function M.run(file, runtime)
	if not file or file == "" then
		return false, "No file specified"
	end

	-- Check if file exists
	if vim.fn.filereadable(file) == 0 then
		return false, "File not readable: " .. file
	end

	-- Auto-detect runtime if not specified
	if not runtime or runtime == "" then
		runtime = detect_runtime(file)
	end

	-- Validate runtime
	if not vim.tbl_contains({ "node", "deno", "bun" }, runtime) then
		return false, "Unknown runtime: " .. runtime .. " (expected: node, deno, bun)"
	end

	-- Check if runtime is available
	local exe = runtime == "node" and "node" or runtime
	if vim.fn.executable(exe) == 0 then
		return false, "Runtime not found: " .. exe .. " (install it or add to PATH)"
	end

	local file_abs = vim.fn.fnamemodify(file, ":p")
	local cwd = vim.fn.fnamemodify(file_abs, ":h")

	-- Get the current session's port if sessions are enabled
	local port = state.opts.port
	if state.opts.sessions_enabled then
		local sessions = require("console_inline.sessions")
		local current_session = sessions.current()
		if current_session then
			port = current_session.port
		end
	end

	-- Build command
	local cmd
	if runtime == "node" then
		local shim = get_shim_path("node")
		if vim.fn.filereadable(shim) == 0 then
			return false, "Node shim not found: " .. shim
		end
		cmd = { "node", "--require", shim, file_abs }
	elseif runtime == "deno" then
		cmd = { "deno", "run", "--allow-all", file_abs }
	elseif runtime == "bun" then
		cmd = { "bun", "run", file_abs }
	end

	-- Check if buffer is modified
	if vim.bo.modified then
		local choice = vim.fn.confirm("Buffer has unsaved changes. Save before running?", "&Yes\n&No\n&Cancel")
		if choice == 1 then
			vim.cmd("write")
		elseif choice == 3 then
			return false, "Execution cancelled"
		end
	end

	-- Execute asynchronously with proper error handling
	local output_lines = {}
	local error_lines = {}

	local function on_stdout(_, data)
		if data and type(data) == "string" then
			for line in data:gmatch("[^\r\n]+") do
				if line ~= "" then
					output_lines[#output_lines + 1] = line
				end
			end
		end
	end

	local function on_stderr(_, data)
		if data and type(data) == "string" then
			for line in data:gmatch("[^\r\n]+") do
				if line ~= "" then
					error_lines[#error_lines + 1] = line
				end
			end
		end
	end

	local function on_exit(_, code)
		local runner_opts = state.opts.runner or {}
		local show_output = runner_opts.show_output ~= false

		-- Show output in split buffer
		if show_output and (#output_lines > 0 or #error_lines > 0) then
			local all_lines = vim.list_extend(output_lines, error_lines)
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)
			vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
			vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
			vim.api.nvim_buf_set_name(buf, "[console-inline-output]")
			vim.cmd("split")
			vim.api.nvim_set_current_buf(buf)
		end

		if code == 0 then
			vim.notify(
				string.format("console-inline: %s execution completed successfully", runtime),
				vim.log.levels.INFO
			)
		else
			local error_msg = #error_lines > 0 and error_lines[1] or "unknown error"
			vim.notify(
				string.format("console-inline: %s execution failed with code %d: %s", runtime, code, error_msg),
				vim.log.levels.ERROR
			)
		end
	end

	-- Spawn process with CONSOLE_INLINE_PORT environment variable
	local env = {}
	-- Copy current environment
	for key, val in pairs(vim.fn.environ()) do
		env[key] = val
	end
	-- Override with session port
	env["CONSOLE_INLINE_PORT"] = tostring(port)
	vim.notify(
		string.format("console-inline: Setting CONSOLE_INLINE_PORT=%d (sessions_enabled=%s)", port, tostring(state.opts.sessions_enabled)),
		vim.log.levels.DEBUG
	)
	
	local ok, handle = pcall(vim.system, cmd, {
		cwd = cwd,
		stdout = on_stdout,
		stderr = on_stderr,
		env = env,
	}, on_exit)

	if not ok then
		return false, "Failed to spawn process: " .. tostring(handle)
	end

	vim.notify(
		string.format("console-inline: Running %s with %s...", vim.fn.fnamemodify(file, ":t"), runtime),
		vim.log.levels.INFO
	)

	-- Note: Process runs asynchronously, callbacks will be called when complete
	return true
end

return M
