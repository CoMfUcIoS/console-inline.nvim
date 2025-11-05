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
local log = require("console_inline.log")

-- Cache per buffer:
-- { parser = <parser>, ts = last_parse_time, tree = <tree>,
--   lang = 'javascript'|'typescript'|'tsx', ctx = { <line->context> },
--   last_change = { start_row, old_end_row, new_end_row } }
M.cache = {}
M.attached_buffers = {}

local function guess_lang(buf)
	local ft = vim.bo[buf].filetype
	if ft == "javascriptreact" then
		return "javascript"
	end
	if ft == "typescriptreact" then
		return "tsx"
	end
	if ft == "javascript" or ft == "typescript" or ft == "tsx" then
		return ft
	end
	-- Heuristic based on extension
	local name = vim.api.nvim_buf_get_name(buf)
	if name:match("%.tsx$") then
		return "tsx"
	end
	if name:match("%.ts$") then
		return "typescript"
	end
	if name:match("%.jsx$") then
		return "javascript"
	end
	if name:match("%.js$") then
		return "javascript"
	end
	return nil
end

local function get_parser(buf)
	local lang = guess_lang(buf)
	if not lang then
		return nil, "unsupported filetype"
	end
	local ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
	if not ok then
		local cache = M.cache[buf] or {}
		if not cache.warned_unavailable then
			cache.warned_unavailable = true
			M.cache[buf] = cache
			log.debug("treesitter parser unavailable once", lang)
		end
		return nil, "parser unavailable for " .. lang
	end
	return parser, nil
end

-- Basic queries: console calls + function / class boundaries.
local function get_query(lang)
	-- Expanded queries: console.* calls, fetch(), new Error(), throw statements, Promise.reject, function & class declarations.
	local src = [[
  (call_expression
    function: (member_expression
      object: (identifier) @console_obj
      property: (property_identifier) @console_method
    )
  ) @console_call

  (call_expression
    function: (identifier) @fetch_fn
    arguments: (arguments) @fetch_args
  ) @fetch_call

  (new_expression
    constructor: (identifier) @error_ctor
    arguments: (arguments)? @error_args
  ) @error_new

  (call_expression
    function: (member_expression
      object: (identifier) @promise_obj
      property: (property_identifier) @reject_method
    )
  ) @promise_reject

  (throw_statement
    argument: (_)? @throw_arg
  ) @throw_stmt

  (function_declaration name: (identifier) @fn_name) @fn_decl
  (class_declaration name: (identifier) @class_name) @class_decl
  ]]
	local ok, query = pcall(vim.treesitter.query.parse, lang, src)
	if not ok then
		return nil
	end
	return query
end

local function build_context(buf, tree, lang)
	local root = tree:root()
	local query = get_query(lang)
	if not query then
		return {}
	end
	local ctx = {}
	for id, node, _ in query:iter_captures(root, buf, 0, root:end_()) do
		local cap = query.captures[id]
		local sr, _, er = node:range()
		local function mark_lines(flag)
			for line = sr, er do
				ctx[line] = ctx[line] or {}
				ctx[line][flag] = true
			end
		end
		if cap == "fn_name" then
			ctx[sr] = ctx[sr] or {}
			ctx[sr].function_name = vim.treesitter.get_node_text(node, buf)
		elseif cap == "class_name" then
			ctx[sr] = ctx[sr] or {}
			ctx[sr].class_name = vim.treesitter.get_node_text(node, buf)
		elseif cap == "console_call" then
			mark_lines("has_console_call")
		elseif cap == "console_method" then
			ctx[sr] = ctx[sr] or {}
			ctx[sr].console_method_name = vim.treesitter.get_node_text(node, buf)
		elseif cap == "fetch_call" then
			mark_lines("has_fetch_call")
		elseif cap == "error_new" then
			mark_lines("has_error_new")
		elseif cap == "promise_reject" then
			mark_lines("has_promise_reject")
		elseif cap == "promise_obj" or cap == "reject_method" then
			-- Verify it's actually Promise.reject
			local text = vim.treesitter.get_node_text(node, buf)
			if (cap == "promise_obj" and text == "Promise") or (cap == "reject_method" and text == "reject") then
				mark_lines("has_promise_reject")
			end
		elseif cap == "throw_stmt" then
			mark_lines("has_throw_stmt")
		end
	end
	return ctx
end

local function build_context_window(buf, tree, lang, start_row, end_row, existing_ctx)
	local root = tree:root()
	local query = get_query(lang)
	if not query then
		return existing_ctx or {}
	end
	local ctx = existing_ctx or {}
	-- purge previous flags in window
	for ln = start_row, end_row do
		ctx[ln] = nil
	end
	for id, node, _ in query:iter_captures(root, buf, start_row, end_row + 1) do
		local cap = query.captures[id]
		local sr, _, er = node:range()
		if sr < start_row then sr = start_row end
		if er > end_row then er = end_row end
		local function mark_lines(flag)
			for line = sr, er do
				ctx[line] = ctx[line] or {}
				ctx[line][flag] = true
			end
		end
		if cap == "fn_name" then
			ctx[sr] = ctx[sr] or {}
			ctx[sr].function_name = vim.treesitter.get_node_text(node, buf)
		elseif cap == "class_name" then
			ctx[sr] = ctx[sr] or {}
			ctx[sr].class_name = vim.treesitter.get_node_text(node, buf)
		elseif cap == "console_call" then
			mark_lines("has_console_call")
		elseif cap == "console_method" then
			ctx[sr] = ctx[sr] or {}
			ctx[sr].console_method_name = vim.treesitter.get_node_text(node, buf)
		elseif cap == "fetch_call" then
			mark_lines("has_fetch_call")
		elseif cap == "error_new" then
			mark_lines("has_error_new")
		elseif cap == "promise_reject" then
			mark_lines("has_promise_reject")
		elseif cap == "promise_obj" or cap == "reject_method" then
			local text = vim.treesitter.get_node_text(node, buf)
			if (cap == "promise_obj" and text == "Promise") or (cap == "reject_method" and text == "reject") then
				mark_lines("has_promise_reject")
			end
		elseif cap == "throw_stmt" then
			mark_lines("has_throw_stmt")
		end
	end
	return ctx
end

local function parse(buf)
	local parser, err = get_parser(buf)
	if not parser then
		return nil, err
	end
	local tree = parser:parse()[1]
	if not tree then
		return nil, "no tree"
	end
	return tree
end

function M.activate()
	log.debug("treesitter.activate: starting")
	-- Verify runtime API availability.
	if not vim.treesitter or not vim.treesitter.get_parser then
		log.debug("treesitter.activate: treesitter not available in this Neovim build")
		return false
	end
	-- Setup autocommands for incremental parsing.
	local group = vim.api.nvim_create_augroup("ConsoleInlineTS", { clear = true })
	local debounce_ms = require("console_inline.state").opts.treesitter_debounce_ms or 120
	local pending = {}
	local function rebuild_full(buf)
		local lang = guess_lang(buf)
		if not lang then
			return
		end
		local tree, perr = parse(buf)
		if not tree then
			log.debug("treesitter.parse failed", perr)
			return
		end
		M.cache[buf] = M.cache[buf] or {}
		M.cache[buf].tree = tree
		M.cache[buf].lang = lang
		M.cache[buf].ctx = build_context(buf, tree, lang)
		M.cache[buf].ts = vim.loop.now()
		M.cache[buf].last_full_ts = M.cache[buf].ts
		local st = require("console_inline.state").treesitter_stats
		st.full_rebuilds = st.full_rebuilds + 1
		pending[buf] = nil
		log.debug("treesitter cache built", { buf = buf, lang = lang })
	end

	local function rebuild_partial(buf, cursor_line)
		local lang = guess_lang(buf)
		if not lang then return end
		local tree, perr = parse(buf)
		if not tree then
			log.debug("treesitter.partial parse failed", perr)
			return
		end
		M.cache[buf] = M.cache[buf] or {}
		local cache = M.cache[buf]
		cache.tree = tree
		cache.lang = lang
		local window = 150
		local start_row = math.max(0, cursor_line - window)
		local end_row = cursor_line + window
		local total = vim.api.nvim_buf_line_count(buf)
		if end_row > total - 1 then end_row = total - 1 end
		cache.ctx = build_context_window(buf, tree, lang, start_row, end_row, cache.ctx)
		cache.ts = vim.loop.now()
		local st = require("console_inline.state").treesitter_stats
		st.partial_rebuilds = st.partial_rebuilds + 1
		pending[buf] = nil
		log.debug("treesitter partial window updated", { buf = buf, start_row = start_row, end_row = end_row })
	end

	local function rebuild_range(buf, start_row, end_row)
		local lang = guess_lang(buf)
		if not lang then return end
		local tree, perr = parse(buf)
		if not tree then
			log.debug("treesitter.range parse failed", perr)
			return
		end
		M.cache[buf] = M.cache[buf] or {}
		local cache = M.cache[buf]
		cache.tree = tree
		cache.lang = lang
		-- Invalidate and rebuild only the affected range
		cache.ctx = build_context_window(buf, tree, lang, start_row, end_row, cache.ctx)
		cache.ts = vim.loop.now()
		local st = require("console_inline.state").treesitter_stats
		st.range_rebuilds = st.range_rebuilds + 1
		pending[buf] = nil
		log.debug("treesitter range updated", { buf = buf, start_row = start_row, end_row = end_row })
	end
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufEnter" }, {
		group = group,
		callback = function(args)
			local buf = args.buf
			if not vim.api.nvim_buf_is_loaded(buf) then
				return
			end
			-- Attach buffer change listener for precise range tracking
			if not M.attached_buffers[buf] then
				M.attached_buffers[buf] = true
				vim.api.nvim_buf_attach(buf, false, {
					on_lines = function(_, buf_handle, _, first_line, old_last_line, new_last_line)
						local cache = M.cache[buf_handle]
						if not cache then return end
						-- Store change range for next rebuild
						cache.last_change = {
							start_row = first_line,
							old_end_row = old_last_line - 1,
							new_end_row = new_last_line - 1,
						}
					end,
					on_detach = function(_, buf_handle)
						M.attached_buffers[buf_handle] = nil
					end,
				})
			end
			rebuild_full(buf)
		end,
	})
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = group,
		callback = function(args)
			local buf = args.buf
			local cache = M.cache[buf]
			if not cache or not cache.tree then
				return
			end
			local now = vim.loop.now()
			if cache.ts and (now - cache.ts) < debounce_ms then
				if not pending[buf] then
					pending[buf] = true
					vim.defer_fn(function()
						-- Only rebuild if no newer parse happened meanwhile
						local c = M.cache[buf]
						if c and c.ts and (vim.loop.now() - c.ts) >= debounce_ms then
							local line = vim.api.nvim_win_get_cursor(0)[1] - 1
							local total = vim.api.nvim_buf_line_count(buf)
							local change = c.last_change
							-- Use precise range if available and small enough
							if change and (change.new_end_row - change.start_row) < 50 then
								rebuild_range(buf, change.start_row, math.min(change.new_end_row, total - 1))
								c.last_change = nil
							elseif total > 3000 then
								rebuild_partial(buf, line)
							else
								rebuild_full(buf)
							end
						else
							pending[buf] = nil
						end
					end, debounce_ms)
				end
				return
			end
			local line = vim.api.nvim_win_get_cursor(0)[1] - 1
			local total = vim.api.nvim_buf_line_count(buf)
			local cache_lines = vim.tbl_count(cache.ctx or {})
			local change = cache.last_change
			-- Prefer range rebuild for small edits
			if change and (change.new_end_row - change.start_row) < 50 then
				rebuild_range(buf, change.start_row, math.min(change.new_end_row, total - 1))
				cache.last_change = nil
			elseif total > 3000 then
				-- Periodically force full rebuild to refresh context drift
				local st = require("console_inline.state").treesitter_stats
				if (st.partial_rebuilds % 20) == 0 then
					rebuild_full(buf)
				else
					rebuild_partial(buf, line)
				end
			else
				rebuild_full(buf)
			end
		end,
	})
	return true
end

-- Retrieve structural context for a line; used by render to tweak scoring.
function M.context_for(buf, line0)
	local cache = M.cache[buf]
	if not cache or not cache.ctx then
		return nil
	end
	return cache.ctx[line0]
end

return M
