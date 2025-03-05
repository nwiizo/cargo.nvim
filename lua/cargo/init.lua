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

	-- Timeout settings
	timeouts = {
		default = 300,  -- Default timeout in seconds
		run = 600,      -- Longer timeout for cargo run
		test = 600,     -- Longer timeout for cargo test
		bench = 900,    -- Longer timeout for cargo bench
		build = 600,    -- Longer timeout for cargo build
	},

	-- Process monitoring
	process_monitoring = {
		enabled = true,
		check_interval = 5,     -- Check process status every 5 seconds
		memory_limit = 1024,    -- Memory limit in MB
		cpu_limit = 90,         -- CPU usage limit in percentage
	},

	-- Interactive mode settings
	interactive = {
		enabled = true,
		prompt_patterns = {
			"^%s*>%s*$",          -- Basic prompt
			"^%s*%[y/N%]:%s*$",   -- Yes/No prompt
			"^%s*Password:%s*$",   -- Password prompt
			"^%s*Input:%s*$",     -- Generic input prompt
		},
		input_field_height = 1,
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

-- Create input field for interactive mode
local function create_input_field(bufnr, winnr, opts)
	local input_bufnr = vim.api.nvim_create_buf(false, true)
	local input_height = opts.interactive.input_field_height
	local input_width = vim.api.nvim_win_get_width(winnr)

	local input_win = vim.api.nvim_open_win(input_bufnr, true, {
		relative = 'win',
		win = winnr,
		row = vim.api.nvim_win_get_height(winnr) - input_height,
		col = 0,
		width = input_width,
		height = input_height,
		style = 'minimal',
		border = 'single',
		title = "Input",
		title_pos = "center",
	})

	-- Set input buffer options
	vim.api.nvim_buf_set_option(input_bufnr, 'modifiable', true)
	vim.api.nvim_buf_set_option(input_bufnr, 'buftype', 'prompt')

	-- Set up prompt callback
	vim.fn.prompt_setcallback(input_bufnr, function(input)
		-- Send input to the process
		if cargo_lib and cargo_lib.send_input then
			cargo_lib.send_input(input .. "\n")
			
			-- 入力履歴をメインバッファに表示
			vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
			vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
				"@info@Input: " .. input
			})
			vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
			
			-- 入力後にプロンプトをクリア
			vim.api.nvim_buf_set_lines(input_bufnr, 0, -1, false, {})
		end
	end)

	-- プロンプト設定
	vim.fn.prompt_setprompt(input_bufnr, "Input> ")
	
	-- 入力フィールドにフォーカス
	vim.api.nvim_set_current_win(input_win)
	vim.cmd("startinsert")

	return input_bufnr, input_win
end

-- Check for prompt patterns in output
local function check_for_prompt(line, patterns)
	for _, pattern in ipairs(patterns) do
		if line:match(pattern) then
			return true
		end
	end
	return false
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

	-- Get timeout for the command
	local timeout = opts.timeouts[cmd_name] or opts.timeouts.default

	-- Execute command
	local ok, result = pcall(function()
		if #args > 0 then
			return cargo_lib[cmd_name](args)
		else
			return cargo_lib[cmd_name]({})
		end
	end)

	if ok then
		local output, is_interactive = unpack(result)
		
		-- 出力の処理
		local lines = process_output(output)
		for _, line in ipairs(lines) do
			if type(line) == "string" then
				vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { line })
			end
		end

		-- インタラクティブモードの場合は自動クローズを無効化
		if is_interactive then
			-- ステータスラインの更新
			vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
				"",
				"@info@Interactive mode active - Enter your input below",
				"@info@Press Ctrl+C to terminate the process",
			})
			
			-- 入力フィールドを作成（すべてのインタラクティブコマンドで有効）
			local input_bufnr, input_win = create_input_field(bufnr, winnr, opts)
			
			-- 入力フィールドが閉じられたときにメインウィンドウにフォーカスを戻す
			vim.api.nvim_buf_attach(input_bufnr, false, {
				on_detach = function()
					if vim.api.nvim_win_is_valid(winnr) then
						vim.api.nvim_set_current_win(winnr)
					end
				end
			})
		else
			-- 通常モードの場合は自動クローズを有効化
			if opts.auto_close then
				vim.defer_fn(function()
					if vim.api.nvim_win_is_valid(winnr) then
						vim.api.nvim_win_close(winnr, true)
					end
				end, opts.close_timeout)
			end
		end

		-- Monitor process if enabled
		if opts.process_monitoring.enabled then
			local monitor_timer = vim.loop.new_timer()
			monitor_timer:start(0, opts.process_monitoring.check_interval * 1000, vim.schedule_wrap(function()
				-- Check process status
				local process_info = vim.loop.get_process_stats(pid)
				if process_info then
					-- Check memory usage
					if process_info.memory > opts.process_monitoring.memory_limit * 1024 * 1024 then
						cargo_lib.interrupt()
						vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
							"@error@Process terminated: Memory limit exceeded",
						})
					end

					-- Check CPU usage
					if process_info.cpu > opts.process_monitoring.cpu_limit then
						cargo_lib.interrupt()
						vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
							"@error@Process terminated: CPU limit exceeded",
						})
					end
				end
			end))

			-- Clean up timer when command completes
			vim.api.nvim_buf_attach(bufnr, false, {
				on_detach = function()
					if monitor_timer then
						monitor_timer:stop()
						monitor_timer:close()
					end
				end
			})
		end
	else
		-- エラー処理
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
			"",
			string.rep("─", vim.api.nvim_win_get_width(winnr) - 2),
			"@error@" .. tostring(result):gsub("\n", " "),
		})
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
