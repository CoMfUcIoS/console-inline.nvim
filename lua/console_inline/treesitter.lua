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
--   lang = 'javascript'|'typescript'|'tsx', ctx = { <line->context> } }
M.cache = {}

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
		elseif cap == "promise_reject" or cap == "reject_method" then
			-- Check if it's actually Promise.reject
			if cap == "promise_obj" then
				local text = vim.treesitter.get_node_text(node, buf)
				if text == "Promise" then
					mark_lines("has_promise_reject")
				end
			elseif cap == "reject_method" then
				local text = vim.treesitter.get_node_text(node, buf)
				if text == "reject" then
					mark_lines("has_promise_reject")
				end
			else
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
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufEnter" }, {
		group = group,
		callback = function(args)
			local buf = args.buf
			if not vim.api.nvim_buf_is_loaded(buf) then
				return
			end
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
			log.debug("treesitter cache built", { buf = buf, lang = lang })
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
			local tree = parse(buf)
			if not tree then
				return
			end
			cache.tree = tree
			cache.ctx = build_context(buf, tree, cache.lang)
			cache.ts = vim.loop.now()
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
