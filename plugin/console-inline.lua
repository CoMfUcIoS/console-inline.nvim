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

-- Note: This file is loaded by Neovim when the plugin directory is discovered.
-- If using lazy.nvim with a config function, that will handle setup() calls.
-- If not using lazy.nvim or not providing a config function, fall back to empty setup.

local ok, mod = pcall(require, "console_inline")
if not ok then
	vim.schedule(function()
		vim.notify("console-inline.nvim: failed to load module", vim.log.levels.ERROR)
	end)
	return
end

-- Don't auto-setup here - let lazy.nvim's config function handle it
-- The config function in your lazy.nvim spec will call setup() with proper opts
