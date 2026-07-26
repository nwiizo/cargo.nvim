-- lua/cargo/init.lua
local vim = _G.vim
local command = require("cargo.command")
local config = require("cargo.config")
local M = {}

-- Debug utilities
local function debug_print(...)
	if vim.g.cargo_nvim_debug then
		print(string.format("[cargo.nvim] %s", table.concat({ ... }, " ")))
	end
end

---@type CargoNvimOptions
local active_opts = config.resolve()

-- Load Cargo library
local function load_cargo_lib()
	if package.loaded.cargo_nvim then
		return package.loaded.cargo_nvim
	end

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
1. Ensure Rust and Cargo 1.97 or newer are installed:
   rustc --version
   cargo --version

2. Run the build command manually:
   cd %s && cargo build --locked --release

3. If using lazy.nvim, ensure your config includes:
   build = "cargo build --locked --release"

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
	package.loaded.cargo_nvim = cargo

	debug_print("Successfully loaded cargo library")
	return cargo
end

-- Global cargo lib instance
local cargo_lib = nil
local registered_commands = {}

-- Set up highlights
local function setup_highlights()
	local highlight_links = {
		CargoError = "DiagnosticError",
		CargoWarning = "DiagnosticWarn",
		CargoSuccess = "DiagnosticOk",
		CargoInfo = "DiagnosticInfo",
		CargoHeader = "Title",
		CargoCommand = "Comment",
		CargoProgress = "MoreMsg",
	}

	local function define_highlights()
		for name, link in pairs(highlight_links) do
			vim.api.nvim_set_hl(0, name, { default = true, link = link })
		end
	end

	define_highlights()

	local group = vim.api.nvim_create_augroup("cargo.nvim", { clear = true })
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

	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = define_highlights,
		desc = "Restore cargo.nvim highlight links",
	})

	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = "cargo-output",
		callback = function(event)
			vim.api.nvim_buf_call(event.buf, function()
				for _, cmd in ipairs(syntax_cmds) do
					vim.cmd(cmd)
				end
				vim.opt_local.conceallevel = 2
				vim.opt_local.concealcursor = "nvc"
			end)
		end,
		desc = "Highlight cargo.nvim output",
	})
end

-- Create floating window
local function create_float_win(opts)
	local max_height = math.max(1, vim.o.lines - 1)
	local width = math.max(1, math.min(vim.o.columns, math.floor(vim.o.columns * opts.window_width)))
	local height = math.max(1, math.min(max_height, math.floor(max_height * opts.window_height)))
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
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].modifiable = true
	vim.wo[winnr].number = opts.show_line_numbers
	vim.wo[winnr].wrap = opts.wrap_output
	vim.wo[winnr].cursorline = opts.show_cursor_line

	local function set_keymap(mode, key, action, desc)
		vim.keymap.set(mode, key, action, {
			buffer = bufnr,
			nowait = true,
			silent = true,
			desc = desc,
		})
	end

	local function close_window()
		if vim.api.nvim_win_is_valid(winnr) then
			vim.api.nvim_win_close(winnr, true)
		end
	end

	set_keymap("n", opts.keymaps.close, close_window, "Close cargo output")
	set_keymap("n", "<Esc>", close_window, "Close cargo output")
	set_keymap("n", opts.keymaps.interrupt, M.interrupt, "Interrupt cargo process")

	if opts.keymaps.send_input then
		set_keymap("n", opts.keymaps.send_input, M.send_input, "Send input to cargo process")
	end

	set_keymap("n", opts.keymaps.scroll_up, "<C-u>", "Scroll cargo output up")
	set_keymap("n", opts.keymaps.scroll_down, "<C-d>", "Scroll cargo output down")
	set_keymap("n", opts.keymaps.scroll_top, "gg", "Go to start of cargo output")
	set_keymap("n", opts.keymaps.scroll_bottom, "G", "Go to end of cargo output")
	set_keymap("n", opts.keymaps.toggle_wrap, function()
		if vim.api.nvim_win_is_valid(winnr) then
			vim.wo[winnr].wrap = not vim.wo[winnr].wrap
		end
	end, "Toggle cargo output wrapping")
	set_keymap("n", opts.keymaps.copy_output, function()
		vim.fn.setreg("+", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "l")
	end, "Copy cargo output")
	set_keymap("n", opts.keymaps.clear_output, function()
		vim.bo[bufnr].modifiable = true
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
		vim.bo[bufnr].modifiable = false
	end, "Clear cargo output")

	-- Publish the FileType event after the plugin-owned buffer is configured.
	vim.bo[bufnr].filetype = "cargo-output"

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
		opts.poll_interval,
		vim.schedule_wrap(function()
			-- The output is no longer visible, so cancel and discard the job.
			if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_win_is_valid(winnr) then
				if cargo_lib.cancel then
					cargo_lib.cancel(job_id)
				else
					cargo_lib.interrupt(job_id)
				end
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
---@param opts? table
function M.setup(opts)
	opts = config.resolve(opts)
	active_opts = opts

	vim.g.cargo_nvim_debug = opts.debug
	if opts.debug then
		debug_print("Debug mode enabled")
	end

	debug_print("Loading cargo library...")
	cargo_lib = cargo_lib or load_cargo_lib()

	setup_highlights()

	for command_name in pairs(registered_commands) do
		pcall(vim.api.nvim_del_user_command, command_name)
	end
	registered_commands = {}

	for cmd_name, cmd_opts in pairs(opts.commands) do
		local command_name = command.user_command_name(cmd_name)
		debug_print("Registering command:", command_name)

		-- The cargo subcommand defaults to the config key, but can be overridden
		-- together with preset arguments so new commands can be added from the
		-- config alone, e.g. { cmd = "test", args = { "--release" } } registers
		-- :CargoTestRelease running `cargo test --release`.
		local subcommand = cmd_opts.cmd or cmd_name
		local preset_args = cmd_opts.args or {}

		vim.api.nvim_create_user_command(command_name, function(args)
			execute_command_native(subcommand, command.merge_args(preset_args, args.fargs), opts)
		end, {
			nargs = cmd_opts.nargs or "*",
			desc = cmd_opts.desc,
		})
		registered_commands[command_name] = true
	end

	-- Register the CargoRunTerm command
	vim.api.nvim_create_user_command("CargoRunTerm", function(args)
		M.run_in_terminal(args.fargs)
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
	registered_commands.CargoRunTerm = true

	debug_print("Plugin setup completed")
end

-- cargo run using terminal mode (especially for proconio usage)
---@param args? string[]
function M.run_in_terminal(args)
	args = args or {}
	local max_height = math.max(1, vim.o.lines - 1)
	local width = math.max(1, math.min(vim.o.columns, math.floor(vim.o.columns * active_opts.window_width)))
	local height = math.max(1, math.min(max_height, math.floor(max_height * active_opts.window_height)))

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.bo[bufnr].bufhidden = "wipe"

	local winnr = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = "minimal",
		border = active_opts.border,
		title = " Cargo RUN (Terminal) ",
		title_pos = "center",
	})

	-- Set window options
	vim.wo[winnr].number = active_opts.show_line_numbers
	vim.wo[winnr].wrap = active_opts.wrap_output
	vim.wo[winnr].cursorline = active_opts.show_cursor_line

	local function close_window()
		if vim.api.nvim_win_is_valid(winnr) then
			vim.api.nvim_win_close(winnr, true)
		end
	end

	local job_opts = {
		on_exit = function()
			vim.schedule(function()
				if not vim.api.nvim_buf_is_valid(bufnr) then
					return
				end

				vim.b[bufnr].cargo_terminal_job_id = nil
				pcall(function()
					vim.bo[bufnr].modifiable = true
					vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
						"",
						"=== Process completed ===",
						"Press q or <Esc> to close this window",
					})
					vim.bo[bufnr].modifiable = false
				end)

				vim.keymap.set("n", active_opts.keymaps.close, close_window, {
					buffer = bufnr,
					silent = true,
					desc = "Close cargo terminal",
				})
				vim.keymap.set("n", "<Esc>", close_window, {
					buffer = bufnr,
					silent = true,
					desc = "Close cargo terminal",
				})

				if vim.api.nvim_get_current_buf() == bufnr then
					vim.cmd("stopinsert")
				end
			end)
		end,
	}

	local argv = command.cargo_argv("run", args)
	local job_id
	if vim.fn.has("nvim-0.11") == 1 then
		job_opts.term = true
		job_id = vim.fn.jobstart(argv, job_opts)
	else
		job_id = vim.fn.termopen(argv, job_opts)
	end

	if job_id <= 0 then
		close_window()
		error(string.format("Failed to start cargo terminal job (error %d)", job_id))
	end
	vim.b[bufnr].cargo_terminal_job_id = job_id

	vim.cmd("startinsert")

	return bufnr, winnr
end

return M
