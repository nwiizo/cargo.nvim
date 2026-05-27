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
	wrap_output = true, -- Enable text wrapping by default
	show_progress = true,

	-- Additional settings
	run_timeout = 300, -- Timeout for cargo run (seconds)
	interactive_timeout = 30, -- Inactivity warning for interactive mode (seconds)
	input_field_height = 1, -- Height of input field

	-- Advanced behavior options
	force_interactive_run = true, -- Always treat cargo run as interactive mode
	max_inactivity_warnings = 3, -- Maximum number of inactivity warnings before termination
	detect_proconio = true, -- Enable detection of proconio usage

	-- 新規オプション
	force_smart_detection = true, -- 常にスマート検出を使用

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

	-- Timeout settings
	timeouts = {
		default = 300, -- Default timeout in seconds
		run = 600, -- Longer timeout for cargo run
		test = 600, -- Longer timeout for cargo test
		bench = 900, -- Longer timeout for cargo bench
		build = 600, -- Longer timeout for cargo build
	},

	-- Process monitoring
	process_monitoring = {
		enabled = true,
		check_interval = 5, -- Check process status every 5 seconds
		memory_limit = 1024, -- Memory limit in MB
		cpu_limit = 90, -- CPU usage limit in percentage
	},

	-- Interactive mode settings
	interactive = {
		enabled = true,
		prompt_patterns = {
			"^%s*>%s*$", -- Basic prompt
			"^%s*%[y/N%]:%s*$", -- Yes/No prompt
			"^%s*Password:%s*$", -- Password prompt
			"^%s*Input:%s*$", -- Generic input prompt
		},
		history_size = 50,
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
		local help_msg = string.format(
			[[Cargo library not found at path: %s

To fix this issue:
1. Ensure you have the required dependencies installed:
   - Ubuntu/Debian: sudo apt install libluajit-5.1-dev
   - macOS: brew install luajit
   - Arch Linux: sudo pacman -S luajit

2. Run the build command manually:
   cd %s && cargo build --release

3. If using lazy.nvim, ensure your config includes:
   build = "cargo build --release"

For more details, see: https://github.com/nwiizo/cargo.nvim#-requirements]],
			lib_path,
			vim.fn.fnamemodify(lib_path, ":h:h:h")
		)
		error(help_msg)
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

	-- Define the syntax patterns for cargo-output filetype
	local syntax_cmds = {
		"syntax match CargoCommand /@command@.*/",
		"syntax match CargoError /@error@.*/",
		"syntax match CargoWarning /@warning@.*/",
		"syntax match CargoSuccess /@success@.*/",
		"syntax match CargoInfo /@info@.*/",
		"syntax match CargoHeader /@header@.*/",
		"syntax match CargoProgress /@progress@.*/",

		-- Hide the tags themselves
		"syntax match CargoHiddenTag /@\\(command\\|error\\|warning\\|success\\|info\\|header\\|progress\\)@/ conceal",
	}

	-- Create an autocmd to apply syntax highlighting when cargo-output filetype is loaded
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "cargo-output",
		callback = function()
			for _, cmd in ipairs(syntax_cmds) do
				vim.cmd(cmd)
			end
			vim.opt_local.conceallevel = 2
			vim.opt_local.concealcursor = "nvc"
		end,
	})
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

	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].modifiable = true
	vim.bo[bufnr].filetype = "cargo-output"

	if opts.show_line_numbers then
		vim.wo[winnr].number = true
	end
	vim.wo[winnr].wrap = opts.wrap_output
	vim.wo[winnr].cursorline = opts.show_cursor_line

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

	-- Send stdin to the running command (for interactive programs)
	if opts.keymaps.send_input then
		set_keymap("n", opts.keymaps.send_input, '<cmd>lua require("cargo").send_input()<CR>')
	end

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

-- Tag one output line with a highlight marker for the cargo-output syntax.
local function format_output_line(line)
	local timestamp = os.date("%H:%M:%S")
	if line:match("^%s*[Ee]rror") then
		return string.format("[%s] @error@%s", timestamp, line)
	elseif line:match("^%s*[Ww]arning") then
		return string.format("[%s] @warning@%s", timestamp, line)
	elseif line:match("^%s*Compiling") or line:match("^%s*Running") or line:match("^%s*Checking") then
		return string.format("[%s] @info@%s", timestamp, line)
	elseif line:match("^%s*Finished") then
		return string.format("[%s] @success@%s", timestamp, line)
	end
	return string.format("[%s] %s", timestamp, line)
end

-- Execute a cargo command: start it in the Rust backend and stream output by
-- polling the job on a libuv timer.
local function execute_command_native(cmd_name, args, opts)
	-- Save all modified buffers before executing command
	vim.cmd("wa")

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

	-- Initial buffer content: show the command being run.
	local args_str = #args > 0 and (" " .. table.concat(args, " ")) or ""
	local cmd_line = string.format("cargo %s%s", cmd_name, args_str)
	vim.bo[bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"@command@" .. cmd_line,
		string.rep("─", vim.api.nvim_win_get_width(winnr) - 2),
		"",
	})
	vim.bo[bufnr].modifiable = false

	-- Start the cargo job in the Rust backend and stream output by polling.
	local job_id = cargo_lib.start(cmd_name, args)
	vim.b[bufnr].cargo_job_id = job_id

	local timer = (vim.uv or vim.loop).new_timer()
	local function stop_timer()
		if timer and not timer:is_closing() then
			timer:stop()
			timer:close()
		end
		timer = nil
	end

	timer:start(
		0,
		opts.poll_interval or 50,
		vim.schedule_wrap(function()
			-- Window/buffer gone: interrupt the job and stop polling.
			if not vim.api.nvim_buf_is_valid(bufnr) then
				cargo_lib.interrupt(job_id)
				stop_timer()
				return
			end

			local lines, finished, success = cargo_lib.poll(job_id)

			if lines and #lines > 0 then
				local formatted = {}
				for _, line in ipairs(lines) do
					formatted[#formatted + 1] = format_output_line(line)
				end
				vim.bo[bufnr].modifiable = true
				vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, formatted)
				vim.bo[bufnr].modifiable = false
				if vim.api.nvim_win_is_valid(winnr) then
					vim.api.nvim_win_set_cursor(winnr, { vim.api.nvim_buf_line_count(bufnr), 0 })
				end
			end

			if finished then
				stop_timer()
				vim.b[bufnr].cargo_job_id = nil
				vim.bo[bufnr].modifiable = true
				vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
					"",
					success and "@success@Command completed successfully." or "@error@Command finished with errors.",
					"@info@Press q to close",
				})
				vim.bo[bufnr].modifiable = false
				if opts.auto_close and success and vim.api.nvim_win_is_valid(winnr) then
					vim.defer_fn(function()
						if vim.api.nvim_win_is_valid(winnr) then
							vim.api.nvim_win_close(winnr, true)
						end
					end, opts.close_timeout)
				end
			end
		end)
	)

	return bufnr, winnr
end

-- Interrupt the cargo command running in the current output buffer.
-- The Rust backend terminates the child; the poll loop renders the result.
function M.interrupt()
	local bufnr = vim.api.nvim_get_current_buf()
	local job_id = vim.b[bufnr].cargo_job_id
	if job_id and cargo_lib and cargo_lib.interrupt then
		vim.api.nvim_echo({ { "Interrupting cargo process...", "WarningMsg" } }, true, {})
		cargo_lib.interrupt(job_id)
	end
end

-- Send a line to the stdin of the cargo command in the current output buffer.
function M.send_input()
	local bufnr = vim.api.nvim_get_current_buf()
	local job_id = vim.b[bufnr].cargo_job_id
	if not (job_id and cargo_lib and cargo_lib.send_input) then
		return
	end
	vim.ui.input({ prompt = "stdin> " }, function(input)
		if input ~= nil then
			cargo_lib.send_input(job_id, input .. "\n")
		end
	end)
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

		-- The cargo subcommand defaults to the config key, but can be overridden
		-- together with preset arguments so new commands can be added from the
		-- config alone, e.g. { cmd = "test", args = { "--release" } } registers
		-- :CargoTestRelease running `cargo test --release`.
		local subcommand = cmd_opts.cmd or cmd_name
		local preset_args = cmd_opts.args or {}

		vim.api.nvim_create_user_command(command_name, function(args)
			-- Start from the configured preset arguments, then append user input
			local cmd_args = {}
			for _, arg in ipairs(preset_args) do
				table.insert(cmd_args, arg)
			end
			if args.args and args.args ~= "" then
				for _, arg in ipairs(vim.split(args.args, "%s+")) do
					if arg and arg ~= "" then
						table.insert(cmd_args, arg)
					end
				end
			end
			execute_command_native(subcommand, cmd_args, opts)
		end, {
			nargs = cmd_opts.nargs or "*",
			desc = cmd_opts.desc,
		})
	end

	-- Register the CargoRunTerm command
	vim.api.nvim_create_user_command("CargoRunTerm", function(args)
		-- Filter out empty arguments
		local cmd_args = {}
		if args.args and args.args ~= "" then
			for _, arg in ipairs(vim.split(args.args, "%s+")) do
				if arg and arg ~= "" then
					table.insert(cmd_args, arg)
				end
			end
		end
		M.run_in_terminal(cmd_args)
	end, {
		nargs = "*",
		desc = "Run cargo in interactive terminal mode (for proconio etc.)",
		complete = function(ArgLead, _, _)
			-- Provide argument completion
			local completions = {
				"--release",
				"--bin",
				"--example",
				"--package",
				"--target",
			}

			local matches = {}
			for _, comp in ipairs(completions) do
				if comp:find(ArgLead, 1, true) == 1 then
					table.insert(matches, comp)
				end
			end

			return matches
		end,
	})

	debug_print("Plugin setup completed")
end

-- cargo run using terminal mode (especially for proconio usage)
function M.run_in_terminal(args)
	-- Get current window size
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)

	-- Create terminal buffer
	local bufnr = vim.api.nvim_create_buf(false, true)

	-- Create floating window
	local winnr = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = "minimal",
		border = "rounded",
		title = " Cargo RUN (Terminal) ",
		title_pos = "center",
	})

	-- Set window options
	vim.wo[winnr].number = true
	vim.wo[winnr].wrap = true
	vim.wo[winnr].cursorline = true

	-- Start terminal with cargo run
	local args_str = table.concat(args, " ")
	local cmd = "cargo run " .. args_str
	local _ = vim.fn.termopen(cmd, {
		on_exit = function()
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(bufnr) then
					vim.bo[bufnr].modifiable = true
					vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
						"",
						"=== Process completed ===",
						"Press q or <Esc> to close this window",
					})
					vim.bo[bufnr].modifiable = false

					-- Add mappings for closing
					vim.api.nvim_buf_set_keymap(bufnr, "n", "q", ":q<CR>", {
						noremap = true,
						silent = true,
					})
					vim.api.nvim_buf_set_keymap(bufnr, "n", "<Esc>", ":q<CR>", {
						noremap = true,
						silent = true,
					})

					-- Exit terminal mode to normal mode
					vim.cmd("stopinsert")
				end
			end)
		end,
	})

	-- Keymapping for closing (when running)
	vim.api.nvim_buf_set_keymap(bufnr, "t", "<C-\\><C-n>", "", {
		callback = function()
			-- Switch to normal mode
			vim.cmd("stopinsert")
			-- Confirmation message for closing
			if vim.fn.confirm("Close terminal?", "&Yes\n&No", 2) == 1 then
				vim.api.nvim_win_close(winnr, true)
			else
				-- Return to terminal mode if canceled
				vim.cmd("startinsert")
			end
		end,
		noremap = true,
		silent = true,
	})

	-- Exit mapping (Ctrl+C, Ctrl+D)
	vim.api.nvim_buf_set_keymap(bufnr, "t", "<C-c>", "<C-c>", { noremap = true })
	vim.api.nvim_buf_set_keymap(bufnr, "t", "<C-d>", "<C-d>", { noremap = true })

	-- Enter terminal mode
	vim.cmd("startinsert")

	return bufnr, winnr
end

return M
