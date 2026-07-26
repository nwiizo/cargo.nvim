local M = {}
local vim = _G.vim

---@class CargoNvimCommandOptions
---@field cmd? string
---@field args? string[]
---@field nargs? string|integer
---@field desc? string

---@class CargoNvimOptions
---@field debug boolean
---@field window_width number
---@field window_height number
---@field border string|string[]
---@field auto_close boolean
---@field close_timeout integer
---@field poll_interval integer
---@field show_line_numbers boolean
---@field show_cursor_line boolean
---@field wrap_output boolean
---@field commands table<string, CargoNvimCommandOptions>
---@field keymaps table<string, string>

---@type CargoNvimOptions
local defaults = {
	debug = false,
	window_width = 0.8,
	window_height = 0.8,
	border = "rounded",
	auto_close = true,
	close_timeout = 30000,
	poll_interval = 50,
	show_line_numbers = true,
	show_cursor_line = true,
	wrap_output = true,

	commands = {
		bench = { nargs = "*", desc = "Run benchmarks" },
		build = { nargs = "*", desc = "Compile package" },
		clean = { nargs = "*", desc = "Clean target directory" },
		doc = { nargs = "*", desc = "Build documentation" },
		new = { nargs = 1, desc = "Create new package" },
		run = { nargs = "*", desc = "Run package" },
		test = { nargs = "*", desc = "Run tests" },
		update = { nargs = "*", desc = "Update dependencies" },
		check = { nargs = "*", desc = "Check package" },
		init = { nargs = "*", desc = "Initialize package" },
		add = { nargs = "+", desc = "Add dependency" },
		remove = { nargs = "+", desc = "Remove dependency" },
		fmt = { nargs = "*", desc = "Format code" },
		clippy = { nargs = "*", desc = "Run clippy" },
		fix = { nargs = "*", desc = "Auto-fix warnings" },
		publish = { nargs = "*", desc = "Publish package" },
		install = { nargs = "+", desc = "Install binary" },
		uninstall = { nargs = "+", desc = "Uninstall binary" },
		search = { nargs = "+", desc = "Search packages" },
		tree = { nargs = "*", desc = "Show dep tree" },
		vendor = { nargs = "*", desc = "Vendor dependencies" },
		audit = { nargs = "*", desc = "Audit dependencies" },
		outdated = { nargs = "*", desc = "Check outdated deps" },
		autodd = { nargs = "*", desc = "Auto-manage dependencies" },
	},

	keymaps = {
		close = "q",
		scroll_up = "<C-u>",
		scroll_down = "<C-d>",
		scroll_top = "gg",
		scroll_bottom = "G",
		interrupt = "<C-c>",
		send_input = "i",
		toggle_wrap = "w",
		copy_output = "y",
		clear_output = "c",
	},
}

local function is_fraction(value)
	return type(value) == "number" and value > 0 and value <= 1
end

local function is_non_negative_integer(value)
	return type(value) == "number" and value >= 0 and value % 1 == 0
end

local function is_positive_integer(value)
	return type(value) == "number" and value > 0 and value % 1 == 0
end

local function validate(name, value, validator, optional, message)
	if optional and value == nil then
		return
	end

	if vim.fn.has("nvim-0.11") == 1 then
		vim.validate(name, value, validator, false, message)
		return
	end

	local spec = { value, validator }
	if message then
		spec[3] = message
	end
	vim.validate({ [name] = spec })
end

local function is_string_or_table(value)
	return type(value) == "string" or type(value) == "table"
end

local function is_valid_nargs(value)
	return value == 0 or value == 1 or value == "0" or value == "1" or value == "*" or value == "?" or value == "+"
end

local function is_list(value)
	return (vim.islist or vim.tbl_islist)(value)
end

local function validate_commands(commands)
	for name, options in pairs(commands) do
		if type(name) ~= "string" or not name:match("^[%a][%w]*$") then
			error("commands: keys must start with a letter and contain only letters or digits", 3)
		end

		local prefix = "commands." .. name
		validate(prefix, options, "table")
		validate(prefix .. ".cmd", options.cmd, "string", true)
		validate(prefix .. ".args", options.args, "table", true)
		validate(prefix .. ".nargs", options.nargs, is_valid_nargs, true, "0, 1, '*', '?', or '+'")
		validate(prefix .. ".desc", options.desc, "string", true)

		if options.args and not is_list(options.args) then
			error(prefix .. ".args: expected a list", 3)
		end

		for index, arg in ipairs(options.args or {}) do
			validate(string.format("%s.args[%d]", prefix, index), arg, "string")
		end
	end
end

local function validate_keymaps(keymaps)
	for name, keymap in pairs(keymaps) do
		validate("keymaps." .. name, keymap, "string")
	end
end

---@param opts? table
---@return CargoNvimOptions
function M.resolve(opts)
	if opts == nil then
		opts = {}
	end
	validate("opts", opts, "table")

	local resolved = vim.tbl_deep_extend("force", defaults, opts)
	validate("debug", resolved.debug, "boolean")
	validate("window_width", resolved.window_width, is_fraction, false, "number in the range (0, 1]")
	validate("window_height", resolved.window_height, is_fraction, false, "number in the range (0, 1]")
	validate("border", resolved.border, is_string_or_table, false, "string or table")
	validate("auto_close", resolved.auto_close, "boolean")
	validate("close_timeout", resolved.close_timeout, is_non_negative_integer, false, "non-negative integer")
	validate("poll_interval", resolved.poll_interval, is_positive_integer, false, "positive integer")
	validate("show_line_numbers", resolved.show_line_numbers, "boolean")
	validate("show_cursor_line", resolved.show_cursor_line, "boolean")
	validate("wrap_output", resolved.wrap_output, "boolean")
	validate("commands", resolved.commands, "table")
	validate("keymaps", resolved.keymaps, "table")

	validate_commands(resolved.commands)
	validate_keymaps(resolved.keymaps)
	return resolved
end

return M
