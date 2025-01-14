-- plugin/cargo.lua
if vim.fn.has("nvim-0.9") == 0 then
	vim.api.nvim_echo({
		{ "cargo.nvim requires at least nvim-0.9", "ErrorMsg" },
		{ "Please upgrade your neovim version", "WarningMsg" },
	}, true, {})
	return
end

if vim.g.loaded_cargo_nvim ~= nil then
	return
end

vim.g.loaded_cargo_nvim = 1

-- Plugin setup will be handled by the user via their configuration
-- Example:
-- require('cargo').setup({
--     float_window = true,
--     auto_close = true,
--     window_height = 15
-- })
