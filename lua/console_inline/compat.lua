local M = {}

function M.supports_right_align()
	local ok = pcall(function()
		vim.api.nvim_buf_set_extmark(0, vim.api.nvim_create_namespace("console_inline_probe"), 0, 0, {
			id = 999999,
			virt_text = { { "" } },
			virt_text_pos = "eol_right_align",
		})
	end)
	return ok
end

return M
