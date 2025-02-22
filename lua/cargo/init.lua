-- lua/cargo/init.lua
local vim = _G.vim
local M = {}

-- Debug utilities
local function debug_print(...)
	if vim.g.cargo_nvim_debug then
		print(string.format("[cargo.nvim] %s", table.concat({ ... }, " ")))
	end
end

-- Default configuration
local default_opts = {
	debug = false,
	float_window = true,
	window_width = 0.8,
	window_height = 0.8,
	border = "rounded",
	auto_close = true,
	close_timeout = 30000,
	show_line_numbers = true,
	show_cursor_line = true,
	wrap_output = false,
	show_progress = true,

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
		toggle_wrap = "w",
		copy_output = "y",
		clear_output = "c",
	},
}

-- Load Cargo library
local function load_cargo_lib()
	local plugin_dir = vim.fn.fnamemodify(vim.fn.resolve(debug.getinfo(1, "S").source:sub(2)), ":h:h:h")
	debug_print("Plugin directory:", plugin_dir)

	local lib_name = vim.fn.has("mac") == 1 and "libcargo_nvim.dylib"
		or vim.fn.has("win32") == 1 and "cargo_nvim.dll"
		or "libcargo_nvim.so"
	local lib_path = plugin_dir .. "/target/release/" .. lib_name
	debug_print("Looking for library at:", lib_path)

	if vim.fn.filereadable(lib_path) == 0 then
		error(string.format("Cargo library not found at path: %s", lib_path))
	end

	local loaded, err = package.loadlib(lib_path, "luaopen_cargo_nvim")
	if not loaded then
		error(string.format("Failed to load library %s: %s", lib_path, err or "unknown error"))
	end

	local cargo = loaded()
	if not cargo then
		error("Failed to initialize cargo module")
	end

	debug_print("Successfully loaded cargo library")
	return cargo
end

-- Global cargo lib instance
local cargo_lib = nil

-- Set up highlights
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

-- Process single line safely
local function format_line(line, with_timestamp)
	if type(line) ~= "string" then
		return nil
	end

	-- Remove all types of line endings and null bytes
	local clean = line:gsub("\r\n", " "):gsub("\n", " "):gsub("\r", " "):gsub("%z", "")

	-- Skip empty lines
	if clean:match("^%s*$") then
		return nil
	end

	-- Add timestamp if requested
	if with_timestamp then
		local timestamp = os.date("%H:%M:%S")

		-- Format based on content
		if clean:match("^error") or clean:match("^Error") then
			return string.format("[%s] @error@%s", timestamp, clean)
		elseif clean:match("^warning") or clean:match("^Warning") then
			return string.format("[%s] @warning@%s", timestamp, clean)
		elseif clean:match("^%s*Compiling") then
			return string.format("[%s] @info@%s", timestamp, clean)
		elseif clean:match("^%s*Running") then
			return string.format("[%s] @info@%s", timestamp, clean)
		elseif clean:match("^%s*Finished") then
			return string.format("[%s] @success@%s", timestamp, clean)
		else
			return string.format("[%s] %s", timestamp, clean)
		end
	end

	return clean
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

	-- Set up key mappings
	local function set_keymap(mode, key, action)
		vim.api.nvim_buf_set_keymap(bufnr, mode, key, action, {
			nowait = true,
			noremap = true,
			silent = true,
		})
	end

	-- Close window mappings
	set_keymap("n", opts.keymaps.close, ":q<CR>")
	set_keymap("n", "<Esc>", ":q<CR>")

	-- Interrupt command mapping
	set_keymap("n", opts.keymaps.interrupt, '<cmd>lua require("cargo").interrupt()<CR>')

	-- Scroll mappings
	set_keymap("n", opts.keymaps.scroll_up, "<C-u>")
	set_keymap("n", opts.keymaps.scroll_down, "<C-d>")
	set_keymap("n", opts.keymaps.scroll_top, "gg")
	set_keymap("n", opts.keymaps.scroll_bottom, "G")

	-- Toggle wrap mapping
	set_keymap("n", opts.keymaps.toggle_wrap, "<cmd>lua vim.wo.wrap = not vim.wo.wrap<CR>")

	-- Copy output mapping
	set_keymap("n", opts.keymaps.copy_output, "<cmd>%y+<CR>")

	-- Clear output mapping
	set_keymap("n", opts.keymaps.clear_output, "<cmd>%delete_<CR>")

	return bufnr, winnr
end

-- Process command output
local function process_output(output)
	if type(output) ~= "string" then
		return { "Invalid output format" }
	end

	local result = {}
	-- Split output into lines and process each line
	for line in output:gmatch("[^\r\n]+") do
		local formatted = format_line(line, true)
		if formatted then
			table.insert(result, formatted)
		end
	end

	return result
end

-- Execute Cargo command
local function execute_command(cmd_name, args, opts)
	-- Save all modified buffers before executing command
	vim.cmd("wa")

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
		keymaps = opts.keymaps,
	})

	-- Set initial content
	vim.api.nvim_buf_set_option(bufnr, "modifiable", true)

	-- Create command string safely
	local args_str = #args > 0 and (" " .. table.concat(args, " ")) or ""
	local cmd_line = string.format("cargo %s%s", cmd_name, args_str)

	-- Initial buffer content
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"@command@" .. cmd_line,
		string.rep("─", vim.api.nvim_win_get_width(winnr) - 2),
		"",
	})

	-- Execute command
	local ok, result = pcall(function()
		if #args > 0 then
			return cargo_lib[cmd_name](args)
		else
			return cargo_lib[cmd_name]({})
		end
	end)

	if ok then
		-- Process and display output line by line
		local lines = process_output(result)
		for _, line in ipairs(lines) do
			if type(line) == "string" then
				vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { line })
			end
		end

		-- Add completion message
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
			"",
			string.rep("─", vim.api.nvim_win_get_width(winnr) - 2),
			"@success@Command completed successfully",
		})

		if opts.auto_close then
			vim.defer_fn(function()
				if vim.api.nvim_win_is_valid(winnr) then
					vim.api.nvim_win_close(winnr, true)
				end
			end, opts.close_timeout)
		end
	else
		-- Handle error
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
			"",
			string.rep("─", vim.api.nvim_win_get_width(winnr) - 2),
			"@error@" .. tostring(result):gsub("\n", " "), -- Replace newlines with spaces
		})
		debug_print("Command failed:", tostring(result))
	end

	vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
	return bufnr, winnr
end

-- Interrupt running cargo command
function M.interrupt()
	if cargo_lib and cargo_lib.interrupt then
		cargo_lib.interrupt()
	end
end

-- Initialize plugin
function M.setup(opts)
	opts = vim.tbl_deep_extend("force", default_opts, opts or {})

	if opts.debug then
		vim.g.cargo_nvim_debug = true
		debug_print("Debug mode enabled")
	end

	debug_print("Loading cargo library...")
	cargo_lib = load_cargo_lib()

	setup_highlights()

	for cmd_name, cmd_opts in pairs(opts.commands) do
		local command_name = "Cargo" .. cmd_name:sub(1, 1):upper() .. cmd_name:sub(2)
		debug_print("Registering command:", command_name)

		vim.api.nvim_create_user_command(command_name, function(args)
			-- Filter out empty arguments
			local cmd_args = {}
			if args.args and args.args ~= "" then
				for _, arg in ipairs(vim.split(args.args, "%s+")) do
					if arg and arg ~= "" then
						table.insert(cmd_args, arg)
					end
				end
			end
			execute_command(cmd_name, cmd_args, opts)
		end, {
			nargs = cmd_opts.nargs,
			desc = cmd_opts.desc,
		})
	end

	debug_print("Plugin setup completed")
end

return M
