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
		elseif clean:match("^%s*Checking") then
			return string.format("[%s] @info@%s", timestamp, clean)
		elseif clean:match("cargo") or clean:match("[Dd]ebug") or clean:match("[Pp]rofile") then
			-- Ensure cargo command lines and build profile info are displayed
			return string.format("[%s] @info@%s", timestamp, clean)
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

-- Process command output (kept for reference but suppressing warning with _G.process_output)
_G.process_output = function(output)
	if type(output) ~= "string" then
		return { "Invalid output format" }
	end

	local cargo_messages = {}
	local program_output = {}

	-- Extract important cargo messages first
	local finished_match = output:match("Finished[^\r\n]+")
	if finished_match then
		table.insert(cargo_messages, string.format("[%s] @success@%s", os.date("%H:%M:%S"), finished_match))
	end

	local checking_match = output:match("Checking[^\r\n]+")
	if checking_match then
		table.insert(cargo_messages, string.format("[%s] @info@%s", os.date("%H:%M:%S"), checking_match))
	end

	local running_match = output:match("Running[^\r\n]+")
	if running_match then
		table.insert(cargo_messages, string.format("[%s] @info@%s", os.date("%H:%M:%S"), running_match))
	end

	local compiling_match = output:match("Compiling[^\r\n]+")
	if compiling_match then
		table.insert(cargo_messages, string.format("[%s] @info@%s", os.date("%H:%M:%S"), compiling_match))
	end

	-- Process line by line, separating cargo and program output
	for line in output:gmatch("[^\r\n]+") do
		-- Skip lines we've already extracted as cargo messages
		if
			line:match("^%s*Finished")
			or line:match("^%s*Checking")
			or line:match("^%s*Running")
			or line:match("^%s*Compiling")
		then
			-- Skip these as they're already handled above
			local _ = true
		-- Cargo-specific messages go into cargo_messages
		elseif
			line:match("^%s*error")
			or line:match("^%s*warning")
			or line:match("cargo")
			or line:match("Downloading")
			or line:match("Installing")
			or line:match("[Dd]ocumentation")
		then
			local formatted = format_line(line, true)
			if formatted then
				table.insert(cargo_messages, formatted)
			end
		-- All other output is treated as program output
		else
			local formatted = line -- For program output, keep it simpler
			if formatted and formatted:len() > 0 and not formatted:match("^%s*$") then
				table.insert(program_output, string.format("[%s] %s", os.date("%H:%M:%S"), formatted))
			end
		end
	end

	-- If no output was processed, add a fallback
	if #program_output == 0 and #cargo_messages == 0 and output:len() > 0 then
		table.insert(program_output, "[" .. os.date("%H:%M:%S") .. "] " .. output:gsub("\r\n", " "):gsub("\n", " "))
	end

	return {
		program_output = program_output,
		cargo_messages = cargo_messages,
	}
end

-- Create input field for interactive mode (kept for reference but suppressing warning with _G.create_input_field)
_G.create_input_field = function(bufnr, winnr, opts)
	local input_bufnr = vim.api.nvim_create_buf(false, true)
	local input_height = opts.input_field_height or 1
	local input_width = vim.api.nvim_win_get_width(winnr)

	local input_win = vim.api.nvim_open_win(input_bufnr, true, {
		relative = "win",
		win = winnr,
		row = vim.api.nvim_win_get_height(winnr) - input_height,
		col = 0,
		width = input_width,
		height = input_height,
		style = "minimal",
		border = "single",
		title = "Input",
		title_pos = "center",
	})

	-- Configure input buffer
	vim.api.nvim_buf_set_option(input_bufnr, "modifiable", true)
	vim.api.nvim_buf_set_option(input_bufnr, "buftype", "prompt")

	-- Set prompt callback
	vim.fn.prompt_setcallback(input_bufnr, function(input)
		-- Set flag when input is sent (for inactivity detection)
		vim.api.nvim_buf_set_var(bufnr, "cargo_last_input_time", os.time())

		-- Send input to process
		if cargo_lib and cargo_lib.send_input then
			cargo_lib.send_input(input .. "\n")

			-- Display input history in main buffer
			vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
			vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
				"@info@Input: " .. input,
			})
			vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

			-- Clear prompt after input
			vim.api.nvim_buf_set_lines(input_bufnr, 0, -1, false, {})
		end
	end)

	-- Set prompt
	vim.fn.prompt_setprompt(input_bufnr, "Input> ")

	-- Focus input field
	vim.api.nvim_set_current_win(input_win)
	vim.cmd("startinsert")

	return input_bufnr
end

-- Execute command using Neovim's native job system
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

	-- Prepare for job
	vim.api.nvim_buf_set_option(bufnr, "modifiable", true)

	-- Start job
	local job_id = vim.fn.jobstart(cmd_line, {
		on_stdout = function(_, data)
			if data and #data > 1 or (data[1] and data[1]:len() > 0) then
				vim.schedule(function()
					if vim.api.nvim_buf_is_valid(bufnr) then
						vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
						-- Process and format the output
						local formatted_lines = {}
						for _, line in ipairs(data) do
							if line and line:len() > 0 then
								local timestamp = os.date("%H:%M:%S")
								if line:match("^error") or line:match("^Error") then
									table.insert(formatted_lines, string.format("[%s] @error@%s", timestamp, line))
								elseif line:match("^warning") or line:match("^Warning") then
									table.insert(formatted_lines, string.format("[%s] @warning@%s", timestamp, line))
								elseif line:match("^%s*Compiling") then
									table.insert(formatted_lines, string.format("[%s] @info@%s", timestamp, line))
								elseif line:match("^%s*Running") then
									table.insert(formatted_lines, string.format("[%s] @info@%s", timestamp, line))
								elseif line:match("^%s*Finished") then
									table.insert(formatted_lines, string.format("[%s] @success@%s", timestamp, line))
								else
									table.insert(formatted_lines, string.format("[%s] %s", timestamp, line))
								end
							end
						end

						if #formatted_lines > 0 then
							vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, formatted_lines)
						end
						vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
					end
				end)
			end
		end,
		on_stderr = function(_, data)
			if data and #data > 1 or (data[1] and data[1]:len() > 0) then
				vim.schedule(function()
					if vim.api.nvim_buf_is_valid(bufnr) then
						vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
						-- Process and format the stderr
						local formatted_lines = {}
						for _, line in ipairs(data) do
							if line and line:len() > 0 then
								local timestamp = os.date("%H:%M:%S")
								if line:match("^error") or line:match("^Error") then
									table.insert(formatted_lines, string.format("[%s] @error@%s", timestamp, line))
								else
									table.insert(formatted_lines, string.format("[%s] @error@%s", timestamp, line))
								end
							end
						end

						if #formatted_lines > 0 then
							vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, formatted_lines)
						end
						vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
					end
				end)
			end
		end,
		on_exit = function(_, exitcode)
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(bufnr) then
					vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
					vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
						"",
						exitcode == 0 and "@success@Command completed successfully."
							or "@error@Command failed with code " .. exitcode,
						"",
						"@info@Press any key to close",
					})
					vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

					-- Auto-close timer
					if opts.auto_close then
						vim.defer_fn(function()
							if vim.api.nvim_win_is_valid(winnr) then
								vim.api.nvim_win_close(winnr, true)
							end
						end, opts.close_timeout)
					end
				end
			end)
		end,
		stdout_buffered = false,
		stderr_buffered = false,
		detach = false,
	})

	-- Associate job ID with buffer
	vim.api.nvim_buf_set_var(bufnr, "cargo_job_id", job_id)

	-- Set up interrupt handler
	vim.keymap.set("n", opts.keymaps.interrupt, function()
		local job = vim.api.nvim_buf_get_var(bufnr, "cargo_job_id")
		if job and vim.fn.jobstop(job) == 1 then
			vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
			vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
				"",
				"@warning@Process interrupted by user",
			})
			vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
		end
	end, { buffer = bufnr, noremap = true, silent = true })

	-- Safety timer to prevent UI hangs
	local safety_timer = vim.loop.new_timer()
	local safety_timeout = (opts.safety_timeout or 30) * 1000 -- convert to ms
	safety_timer:start(
		safety_timeout,
		safety_timeout,
		vim.schedule_wrap(function()
			-- Check if job is still running
			if vim.fn.jobwait({ job_id }, 0)[1] == -1 then
				-- Check if UI is still responsive
				if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_win_is_valid(winnr) then
					vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
					vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
						"",
						"@warning@Task running for extended period. Enter input or press Ctrl+C to interrupt.",
					})
					vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
				else
					-- Fallback: stop job
					vim.fn.jobstop(job_id)
					safety_timer:stop()
					safety_timer:close()
				end
			else
				-- Job finished, stop timer
				safety_timer:stop()
				safety_timer:close()
			end
		end)
	)

	return bufnr, winnr
end

-- Interrupt running cargo command
function M.interrupt()
	-- Display message
	vim.api.nvim_echo({ { "Interrupting cargo process...", "WarningMsg" } }, true, {})

	-- Call interrupt function from Rust library
	if cargo_lib and cargo_lib.interrupt then
		cargo_lib.interrupt()

		-- If current window is valid, display that process was interrupted
		local bufnr = vim.api.nvim_get_current_buf()
		if vim.api.nvim_buf_get_option(bufnr, "filetype") == "cargo-output" then
			vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
			vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
				"",
				"@error@Process interrupted by user",
				"@info@Press any key to close this window",
			})
			vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
		end
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
			execute_command_native(cmd_name, cmd_args, opts)
		end, {
			nargs = cmd_opts.nargs,
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
	vim.api.nvim_win_set_option(winnr, "number", true)
	vim.api.nvim_win_set_option(winnr, "wrap", true)
	vim.api.nvim_win_set_option(winnr, "cursorline", true)

	-- Start terminal with cargo run
	local args_str = table.concat(args, " ")
	local cmd = "cargo run " .. args_str
	local _ = vim.fn.termopen(cmd, {
		on_exit = function()
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(bufnr) then
					vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
					vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
						"",
						"=== Process completed ===",
						"Press q or <Esc> to close this window",
					})
					vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

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
