local state = require("console_inline.state")
local buf = require("console_inline.buf")

local M = {}

local function ensure_list(value)
	if value == nil then
		return {}
	end
	if type(value) == "string" then
		return { value }
	end
	if vim.tbl_islist(value) then
		return value
	end
	return {}
end

local function match_glob(text, glob)
	if type(text) ~= "string" or text == "" then
		return false
	end
	local ok, regpat = pcall(vim.fn.glob2regpat, glob)
	if not ok then
		return false
	end
	local re = vim.regex(regpat)
	return re and re:match_str(text) ~= nil
end

local function match_lua_pattern(text, pattern)
	if type(text) ~= "string" then
		return false
	end
	local ok, start_pos = pcall(string.find, text, pattern)
	if not ok then
		return false
	end
	return start_pos ~= nil
end

local function match_rule(text, rule, is_path)
	if type(rule) == "string" then
		if is_path then
			return match_glob(text, rule)
		end
		return text:find(rule, 1, true) ~= nil
	end
	if type(rule) ~= "table" then
		return false
	end
	if rule.glob then
		return match_glob(text, rule.glob)
	end
	local pattern = rule.pattern or rule.text
	if pattern then
		if rule.plain then
			return text:find(pattern, 1, true) ~= nil
		end
		return match_lua_pattern(text, pattern)
	end
	if rule.contains then
		return text:find(rule.contains, 1, true) ~= nil
	end
	return false
end

local function matches_any(text, rules, is_path)
	if not text then
		return false
	end
	for _, rule in ipairs(rules) do
		if match_rule(text, rule, is_path) then
			return true
		end
	end
	return false
end

local function collect_rules(rule, keys)
	local acc = {}
	for _, key in ipairs(keys) do
		local value = rule[key]
		if value ~= nil then
			for _, item in ipairs(ensure_list(value)) do
				acc[#acc + 1] = item
			end
		end
	end
	return acc
end

local function should_allow(filters, path, payload)
	local allow = filters.allow
	if type(allow) == "table" then
		local path_rules = collect_rules(allow, { "paths", "path", "files", "file" })
		if #path_rules > 0 and not matches_any(path, path_rules, true) then
			return false
		end
		local message_rules = collect_rules(allow, { "messages", "message", "payload", "pattern" })
		if #message_rules > 0 and not matches_any(payload, message_rules, false) then
			return false
		end
	end
	local deny = filters.deny
	if type(deny) == "table" then
		local deny_paths = collect_rules(deny, { "paths", "path", "files", "file" })
		if #deny_paths > 0 and matches_any(path, deny_paths, true) then
			return false
		end
		local deny_messages = collect_rules(deny, { "messages", "message", "payload", "pattern" })
		if #deny_messages > 0 and matches_any(payload, deny_messages, false) then
			return false
		end
	end
	return true
end

local function apply_severity_rules(filters, path, payload)
	local base = state.opts.severity_filter or {}
	local effective = {}
	for level, value in pairs(base) do
		effective[level] = value
	end
	local rules = filters.severity
	if type(rules) ~= "table" then
		return effective
	end
	for _, rule in ipairs(rules) do
		if type(rule) == "table" then
			local path_rules = collect_rules(rule, { "paths", "path", "files", "file" })
			if #path_rules > 0 and not matches_any(path, path_rules, true) then
				goto continue
			end
			local message_rules = collect_rules(rule, { "messages", "message", "payload", "pattern" })
			if #message_rules > 0 and not matches_any(payload, message_rules, false) then
				goto continue
			end
			if type(rule.allow) == "table" then
				for level, value in pairs(rule.allow) do
					effective[level] = value and true or false
				end
			end
			if type(rule.deny) == "table" then
				for level, value in pairs(rule.deny) do
					if value then
						effective[level] = false
					end
				end
			end
			local only_list = ensure_list(rule.only)
			if #only_list > 0 then
				for _, level in ipairs({ "log", "info", "warn", "error" }) do
					effective[level] = vim.tbl_contains(only_list, level)
				end
			end
		end
		::continue::
	end
	return effective
end

function M.should_render(msg, payload)
	local filters = state.opts.filters
	if type(filters) ~= "table" then
		return true
	end
	local path = buf.canon(msg.file or "")
	return should_allow(filters, path, payload)
end

function M.severity_allows(kind, msg, payload)
	local base = state.opts.severity_filter or {}
	local allowed = base[kind]
	if allowed == nil then
		allowed = true
	end
	local filters = state.opts.filters
	if type(filters) ~= "table" then
		return allowed ~= false
	end
	local path = buf.canon(msg.file or "")
	local map = apply_severity_rules(filters, path, payload)
	local value = map[kind]
	if value == nil then
		return allowed ~= false
	end
	return value ~= false
end

return M
