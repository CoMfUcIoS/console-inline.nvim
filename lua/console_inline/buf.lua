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

local M = {}

local function strip_query(path)
	return path:gsub("[%?#].*$", "")
end

local function canon_local(p)
	if not p or p == "" then
		return ""
	end
	-- normalize "at <frame>" and "(path)" wrappers
	p = p:gsub("^%s*at%s+", "")
	p = p:gsub("^%(", ""):gsub("%)$", "")
	-- trim to last parenthesis content if present
	local inside = p:match("%((.*)%)$")
	if inside then
		p = inside
	end
	-- strip URL schemes
	local scheme, rest = p:match("^(%a[%w%+%-%.]*)://(.+)$")
	if scheme then
		local slash = rest:find("/")
		if slash then
			p = rest:sub(slash)
		else
			p = rest
		end
	end
	p = strip_query(p)
	-- strip file://
	p = p:gsub("^file://", "")
	-- realpath if possible
	local rp = (vim.loop and vim.loop.fs_realpath) and vim.loop.fs_realpath(p) or p
	rp = rp or p
	if p:match("^%./") and rp == p then
		rp = vim.fn.fnamemodify(p, ":p")
	end
	return vim.fn.fnamemodify(rp, ":p")
end

local function tail(path)
	return path:match("[^/\\]+$") or path
end

function M.canon(path)
	return canon_local(path)
end

function M.find_buf_by_path(path)
	local target = canon_local(path)
	if target == "" then
		return nil
	end
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local name = canon_local(vim.api.nvim_buf_get_name(buf))
		if name == target then
			return buf
		end
	end
	local target_tail = tail(target)
	if target_tail and target_tail ~= "" then
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			local name = vim.api.nvim_buf_get_name(buf)
			if tail(name) == target_tail then
				return buf
			end
		end
	end
	return nil
end

function M.ensure_buffer(path)
	if type(path) == "string" and path:match("^%a[%w%+%-%.]*://") then
		return nil
	end
	local buf = M.find_buf_by_path(path)
	if buf then
		return buf
	end
	local target = canon_local(path)
	if target == "" then
		return nil
	end
	vim.cmd("edit " .. vim.fn.fnameescape(target))
	return vim.api.nvim_get_current_buf()
end

return M
