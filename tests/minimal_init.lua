local cwd = vim.loop.cwd()

vim.opt.runtimepath:append(cwd)

local packpath = cwd .. "/.tests/site"
vim.opt.packpath:append(packpath)
vim.opt.runtimepath:append(packpath .. "/pack/deps/start/plenary.nvim")

vim.cmd("packadd plenary.nvim")

package.path = table.concat({ cwd .. "/lua/?.lua", cwd .. "/lua/?/init.lua", package.path }, ";")
