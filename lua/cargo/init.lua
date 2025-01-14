-- lua/cargo/init.lua
local M = {}

-- Default configuration
local default_opts = {
	-- Window settings
	float_window = true,
	window_width = 0.85,
	window_height = 0.8,
	border = "rounded",

	-- Auto-close settings
	auto_close = true,
	close_timeout = 30000,

	-- Display settings
	show_line_numbers = true,
	show_cursor_line = true,
	wrap_output = false,

	-- Cargo commands
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
	},

	-- Keymaps
	keymaps = {
		close = "q",
		scroll_up = "<C-u>",
		scroll_down = "<C-d>",
		scroll_top = "gg",
		scroll_bottom = "G",
		interrupt = "<C-c>",
		toggle_wrap = "w",
		copy_output = "y",
		clear_output = "c",
	},
}

-- Load Cargo library
local function load_cargo_lib()
	local plugin_dir = vim.fn.fnamemodify(vim.fn.resolve(debug.getinfo(1, "S").source:sub(2)), ":h:h:h")
	local lib_name = vim.fn.has("mac") == 1 and "libcargo_nvim.dylib"
		or vim.fn.has("win32") == 1 and "cargo_nvim.dll"
		or "libcargo_nvim.so"
	local lib_path = plugin_dir .. "/target/release/" .. lib_name

	if vim.fn.filereadable(lib_path) == 0 then
		error(string.format("Cargo library not found: %s", lib_path))
	end

	local loaded = package.loadlib(lib_path, "luaopen_cargo_nvim")
	if not loaded then
		error(string.format("Failed to load library: %s", lib_path))
	end

	local cargo = loaded()
	if not cargo then
		error("Failed to initialize cargo module")
	end

	return cargo
end

-- Global cargo lib instance
local cargo_lib = nil

-- Set up syntax highlighting
local function setup_highlights()
	local highlights = {
		CargoError = { fg = "#ff5555", bold = true },
		CargoWarning = { fg = "#ffb86c", bold = true },
		CargoSuccess = { fg = "#50fa7b", bold = true },
		CargoInfo = { fg = "#8be9fd" },
		CargoHeader = { fg = "#bd93f9", bold = true },
		CargoCommand = { fg = "#6272a4", italic = true },
		CargoProgress = { fg = "#50fa7b" },
	}

	for name, attrs in pairs(highlights) do
		vim.api.nvim_set_hl(0, name, attrs)
	end
end

-- Create floating window
local function create_float_win(opts)
	local width = math.floor(vim.o.columns * opts.window_width)
	local height = math.floor(vim.o.lines * opts.window_height)
	local bufnr = vim.api.nvim_create_buf(false, true)

	local win_opts = {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = "minimal",
		border = opts.border,
		title = opts.title,
		title_pos = "center",
	}

	local winnr = vim.api.nvim_open_win(bufnr, true, win_opts)

	vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
	vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
	vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
	vim.api.nvim_buf_set_option(bufnr, "filetype", "cargo-output")

	if opts.show_line_numbers then
		vim.api.nvim_win_set_option(winnr, "number", true)
	end
	vim.api.nvim_win_set_option(winnr, "wrap", opts.wrap_output)
	vim.api.nvim_win_set_option(winnr, "cursorline", opts.show_cursor_line)

	return bufnr, winnr
end

-- Process command output
local function process_output(lines)
	local processed = {}
	for _, line in ipairs(lines) do
		local timestamp = os.date("%H:%M:%S")
		local prefixed_line = string.format("[%s] ", timestamp)

		if line:match("^error") then
			table.insert(processed, prefixed_line .. "@error@" .. line)
		elseif line:match("^warning") then
			table.insert(processed, prefixed_line .. "@warning@" .. line)
		elseif line:match("^%s*Compiling") then
			table.insert(processed, prefixed_line .. "@info@" .. line)
		elseif line:match("^%s*Running") then
			table.insert(processed, prefixed_line .. "@info@" .. line)
		elseif line:match("^%s*Finished") then
			table.insert(processed, prefixed_line .. "@success@" .. line)
		else
			table.insert(processed, prefixed_line .. line)
		end
	end
	return processed
end

-- Execute Cargo command
local function execute_command(cmd_name, args, opts)
	if not cargo_lib then
		error("Cargo library not loaded. Did you call setup()?")
		return
	end

	local bufnr, winnr = create_float_win({
		title = string.format(" Cargo %s ", cmd_name:upper()),
		window_width = opts.window_width,
		window_height = opts.window_height,
		border = opts.border,
		show_line_numbers = opts.show_line_numbers,
		wrap_output = opts.wrap_output,
		show_cursor_line = opts.show_cursor_line,
	})

	-- Display command
	local cmd_line = string.format("cargo %s %s", cmd_name, table.concat(args, " "))
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"@command@" .. cmd_line,
		string.rep("─", vim.api.nvim_win_get_width(winnr) - 2),
		"",
	})

	-- Set up keymaps
	local function map(key, action)
		vim.api.nvim_buf_set_keymap(bufnr, "n", key, action, {
			noremap = true,
			silent = true,
		})
	end

	for key, mapping in pairs(opts.keymaps) do
		if type(mapping) == "string" then
			map(mapping, ":q<CR>")
		end
	end

	-- Execute the cargo command through the Rust library
	local ok, result = pcall(function()
		-- Check if the command exists in cargo_lib
		if cargo_lib[cmd_name] then
			return cargo_lib[cmd_name](args)
		else
			error(string.format("Command '%s' not found in cargo library", cmd_name))
		end
	end)

	if ok then
		-- Process and display the output
		local output_lines = vim.split(result, "\n")
		local processed = process_output(output_lines)
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, processed)

		-- Add success message
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
			"",
			string.rep("─", vim.api.nvim_win_get_width(winnr) - 2),
			"@success@Command completed successfully",
		})

		-- Auto-close if enabled
		if opts.auto_close then
			vim.defer_fn(function()
				if vim.api.nvim_win_is_valid(winnr) then
					vim.api.nvim_win_close(winnr, true)
				end
			end, opts.close_timeout)
		end
	else
		-- Display error message
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
			"",
			string.rep("─", vim.api.nvim_win_get_width(winnr) - 2),
			"@error@" .. tostring(result),
		})
	end

	return bufnr, winnr
end

-- Initialize plugin
function M.setup(opts)
	opts = vim.tbl_deep_extend("force", default_opts, opts or {})

	-- Load the Cargo library
	cargo_lib = load_cargo_lib()

	-- Set up highlights
	setup_highlights()

	-- Register Neovim commands
	for cmd_name, cmd_opts in pairs(opts.commands) do
		vim.api.nvim_create_user_command("Cargo" .. cmd_name:sub(1, 1):upper() .. cmd_name:sub(2), function(args)
			local cmd_args = vim.split(args.args, " ")
			execute_command(cmd_name, cmd_args, opts)
		end, {
			nargs = cmd_opts.nargs,
			desc = cmd_opts.desc,
		})
	end
end

return M
