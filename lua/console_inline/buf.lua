local M = {}

local function canon(p)
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
	-- strip file://
	p = p:gsub("^file://", "")
	-- realpath if possible
    local rp = (vim.loop and vim.loop.fs_realpath) and vim.loop.fs_realpath(p) or p
    rp = rp or p
    return vim.fn.fnamemodify(rp, ":p")
end

function M.find_buf_by_path(path)
	local target = canon(path)
	if target == "" then
		return nil
	end
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local name = canon(vim.api.nvim_buf_get_name(buf))
		if name == target then
			return buf
		end
	end
	return nil
end

function M.ensure_buffer(path)
	local buf = M.find_buf_by_path(path)
	if buf then
		return buf
	end
	local target = canon(path)
	vim.cmd("edit " .. vim.fn.fnameescape(target))
	return vim.api.nvim_get_current_buf()
end

return M
