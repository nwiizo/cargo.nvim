local M = {}

-- ライブラリ読み込み関数
local function load_cargo_lib()
	local plugin_dir = vim.fn.fnamemodify(vim.fn.resolve(debug.getinfo(1, "S").source:sub(2)), ":h:h:h")
	local lib_name = vim.fn.has("mac") == 1 and "libcargo_nvim.dylib"
		or vim.fn.has("win32") == 1 and "cargo_nvim.dll"
		or "libcargo_nvim.so"
	local lib_path = plugin_dir .. "/target/release/" .. lib_name

	if vim.fn.filereadable(lib_path) == 0 then
		error(string.format("Cargo library not found at: %s", lib_path))
	end

	local loaded = package.loadlib(lib_path, "luaopen_cargo_nvim")
	if loaded == nil then
		error(string.format("Failed to load library: %s", lib_path))
	end

	local cargo = loaded()
	if cargo == nil then
		error("Failed to initialize cargo module")
	end

	return cargo
end

-- フローティングウィンドウ作成
local function create_float_win(opts)
	local width = math.floor(vim.o.columns * (opts.window_width or 0.8))
	local height = math.floor(vim.o.lines * (opts.window_height or 0.8))
	local bufnr = vim.api.nvim_create_buf(false, true)

	local win_opts = {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = "minimal",
		border = opts.border or "rounded",
		title = opts.title,
		title_pos = "center",
	}

	local winnr = vim.api.nvim_open_win(bufnr, true, win_opts)

	-- バッファ設定
	vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
	vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
	vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
	vim.api.nvim_buf_set_option(bufnr, "filetype", "cargo-output")

	-- シンタックスハイライト設定
	vim.api.nvim_win_set_option(winnr, "wrap", false)
	vim.api.nvim_win_set_option(winnr, "cursorline", true)

	return bufnr, winnr
end

-- 出力のハイライト設定
local function setup_highlights()
	local highlights = {
		CargoError = { fg = "#ff0000", bold = true },
		CargoWarning = { fg = "#ffa500", bold = true },
		CargoSuccess = { fg = "#00ff00", bold = true },
		CargoInfo = { fg = "#0087ff" },
		CargoHeader = { fg = "#875fff", bold = true },
		CargoCommand = { fg = "#00afff", italic = true },
	}

	for name, attrs in pairs(highlights) do
		vim.api.nvim_set_hl(0, name, attrs)
	end
end

-- 出力の加工とハイライト適用
local function process_output(lines)
	local processed = {}
	for _, line in ipairs(lines) do
		if line:match("^error") then
			table.insert(processed, "@error@" .. line)
		elseif line:match("^warning") then
			table.insert(processed, "@warning@" .. line)
		elseif line:match("^%s*Compiling") then
			table.insert(processed, "@info@" .. line)
		elseif line:match("^%s*Finished") then
			table.insert(processed, "@success@" .. line)
		else
			table.insert(processed, line)
		end
	end
	return processed
end

-- コマンド実行とウィンドウ表示
local function execute_command(cmd_name, args, opts)
	local bufnr, winnr = create_float_win({
		title = string.format(" Cargo %s ", cmd_name),
		window_width = opts.window_width,
		window_height = opts.window_height,
		border = opts.border,
	})

	-- コマンドライン表示
	local cmd_line = string.format("cargo %s %s", cmd_name, table.concat(args, " "))
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"Command: " .. cmd_line,
		string.rep("─", vim.api.nvim_win_get_width(winnr) - 2),
		"",
	})

	-- キーマップ設定
	local keymaps = {
		["q"] = ":q<CR>",
		["<Esc>"] = ":q<CR>",
		["<C-c>"] = function()
			-- TODO: ジョブの停止処理を実装
			vim.api.nvim_win_close(winnr, true)
		end,
	}

	for key, mapping in pairs(keymaps) do
		if type(mapping) == "string" then
			vim.api.nvim_buf_set_keymap(bufnr, "n", key, mapping, { noremap = true, silent = true })
		else
			vim.api.nvim_buf_set_keymap(bufnr, "n", key, "", {
				noremap = true,
				silent = true,
				callback = mapping,
			})
		end
	end

	-- 非同期実行
	local job_id = vim.fn.jobstart(cmd_line, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data and #data > 1 then
				vim.schedule(function()
					if vim.api.nvim_buf_is_valid(bufnr) then
						local processed = process_output(data)
						vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, processed)
					end
				end)
			end
		end,
		on_stderr = function(_, data)
			if data and #data > 1 then
				vim.schedule(function()
					if vim.api.nvim_buf_is_valid(bufnr) then
						local processed = process_output(data)
						vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, processed)
					end
				end)
			end
		end,
		on_exit = function(_, code)
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(bufnr) then
					local status = code == 0 and "@success@Command completed successfully"
						or string.format("@error@Command failed with exit code: %d", code)

					vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
						"",
						string.rep("─", vim.api.nvim_win_get_width(winnr) - 2),
						status,
					})

					-- 自動クローズ設定
					if opts.auto_close and code == 0 then
						vim.defer_fn(function()
							if vim.api.nvim_win_is_valid(winnr) then
								vim.api.nvim_win_close(winnr, true)
							end
						end, opts.close_timeout or 5000)
					end
				end
			end)
		end,
	})

	-- バッファを離れたときの処理
	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = bufnr,
		callback = function()
			if opts.auto_close then
				vim.defer_fn(function()
					if vim.api.nvim_win_is_valid(winnr) then
						vim.api.nvim_win_close(winnr, true)
					end
				end, 100)
			end
		end,
		once = true,
	})

	return job_id, bufnr, winnr
end

function M.setup(opts)
	opts = vim.tbl_deep_extend("force", {
		-- ウィンドウ設定
		float_window = true,
		window_width = 0.8,
		window_height = 0.8,
		border = "rounded",

		-- 自動クローズ設定
		auto_close = true,
		close_timeout = 5000,

		-- コマンド設定
		commands = {
			bench = { nargs = "*" },
			build = { nargs = "*" },
			clean = { nargs = "*" },
			doc = { nargs = "*" },
			new = { nargs = 1 },
			run = { nargs = "*" },
			test = { nargs = "*" },
			update = { nargs = "*" },
		},

		-- カスタムキーマップ
		keymaps = {},
	}, opts or {})

	-- ハイライト設定
	setup_highlights()

	-- ライブラリロード
	local cargo = load_cargo_lib()

	-- コマンド登録
	for cmd_name, cmd_opts in pairs(opts.commands) do
		local user_cmd = "Cargo" .. cmd_name:sub(1, 1):upper() .. cmd_name:sub(2)
		vim.api.nvim_create_user_command(user_cmd, function(args)
			local cmd_args = vim.split(args.args, " ")
			execute_command(cmd_name, cmd_args, opts)
		end, {
			nargs = cmd_opts.nargs,
			desc = string.format("Execute cargo %s", cmd_name),
			complete = function(ArgLead, CmdLine, CursorPos)
				-- TODO: コマンド補完の実装
				return {}
			end,
		})
	end
end

return M
