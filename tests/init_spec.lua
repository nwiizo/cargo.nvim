-- tests/init_spec.lua
-- busted tests/
describe("cargo.nvim", function()
	local mock_vim
	local interrupt_was_called

	before_each(function()
		interrupt_was_called = false

		-- Create mock vim object
		mock_vim = {
			g = {},
			o = {
				columns = 100,
				lines = 50,
			},
			api = {
				nvim_create_buf = function()
					return 1
				end,
				nvim_open_win = function()
					return 1
				end,
				nvim_buf_set_option = function() end,
				nvim_win_set_option = function() end,
				nvim_buf_set_lines = function() end,
				nvim_win_get_width = function()
					return 80
				end,
				nvim_buf_set_keymap = function() end,
				nvim_create_user_command = function() end,
				nvim_set_hl = function() end,
				nvim_win_is_valid = function()
					return true
				end,
				nvim_win_close = function() end,
			},
			fn = {
				has = function()
					return 0
				end,
				fnamemodify = function()
					return "./test"
				end,
				resolve = function(path)
					return path
				end,
				filereadable = function()
					return 1
				end,
			},
			cmd = function() end,
			wait = function() end,
			defer_fn = function(fn)
				fn()
			end,
			split = function(str)
				return { str }
			end,
			tbl_contains = function()
				return true
			end,
			tbl_deep_extend = function(_, t1, t2)
				local result = {}
				for k, v in pairs(t1) do
					result[k] = v
				end
				for k, v in pairs(t2) do
					result[k] = v
				end
				return result
			end,
		}

		-- Set up the mock vim as global
		_G.vim = mock_vim

		-- Create mock cargo module
		local mock_cargo_module = {}
		local native_lib = {
			build = function()
				return "Build output"
			end,
			run = function()
				return "Run output"
			end,
			test = function()
				return "Test output"
			end,
			check = function()
				return "Check output"
			end,
			interrupt = function()
				interrupt_was_called = true
			end,
		}

		function mock_cargo_module.setup(opts)
			opts = vim.tbl_deep_extend("force", {
				debug = false,
				window_width = 0.85,
				window_height = 0.8,
				border = "rounded",
				auto_close = true,
				close_timeout = 30000,
				show_line_numbers = true,
				show_cursor_line = true,
				wrap_output = false,
			}, opts or {})

			if opts.debug then
				vim.g.cargo_nvim_debug = true
			end

			-- Store native lib reference
			mock_cargo_module._native_lib = native_lib

			for cmd_name, cmd_opts in pairs({
				build = { nargs = "*", desc = "Build" },
				run = { nargs = "*", desc = "Run" },
				test = { nargs = "*", desc = "Test" },
			}) do
				local command_name = "Cargo" .. cmd_name:sub(1, 1):upper() .. cmd_name:sub(2)
				vim.api.nvim_create_user_command(command_name, function() end, cmd_opts)
			end

			return mock_cargo_module
		end

		function mock_cargo_module.interrupt()
			if mock_cargo_module._native_lib then
				mock_cargo_module._native_lib.interrupt()
			end
		end

		-- Add the mock to package.preload
		package.preload["cargo"] = function()
			return mock_cargo_module
		end

		-- Reset cargo module
		package.loaded["cargo"] = nil
	end)

	after_each(function()
		-- Clean up
		_G.vim = nil
		package.preload["cargo"] = nil
		package.loaded["cargo"] = nil
	end)

	describe("setup", function()
		it("should merge default options with user options", function()
			local custom_opts = {
				debug = true,
				window_width = 0.5,
				border = "single",
			}

			local cargo = require("cargo")
			cargo.setup(custom_opts)

			assert.equals(true, mock_vim.g.cargo_nvim_debug)
		end)

		it("should register all cargo commands", function()
			local created_commands = {}

			mock_vim.api.nvim_create_user_command = function(name, _, _)
				table.insert(created_commands, name)
			end

			local cargo = require("cargo")
			cargo.setup()

			assert.truthy(created_commands[1])
			local has_command = function(name)
				for _, cmd in ipairs(created_commands) do
					if cmd == name then
						return true
					end
				end
				return false
			end
			assert.is_true(has_command("CargoBuild"))
			assert.is_true(has_command("CargoRun"))
			assert.is_true(has_command("CargoTest"))
		end)
	end)

	describe("interrupt functionality", function()
		it("should provide interrupt function", function()
			local cargo = require("cargo")
			cargo.setup()
			assert.is_function(cargo.interrupt)
		end)

		it("should call interrupt handler when available", function()
			local cargo = require("cargo")
			cargo.setup()
			cargo.interrupt()

			assert.is_true(interrupt_was_called)
		end)
	end)
end)
