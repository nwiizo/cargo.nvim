vim.opt.runtimepath:prepend(vim.fn.getcwd())

local command = require("cargo.command")
local config = require("cargo.config")

assert(vim.deep_equal(command.cargo_argv("run", { "--package", "my crate" }), {
	"cargo",
	"run",
	"--package",
	"my crate",
}))

local resolved = config.resolve({
	window_width = 0.5,
	commands = {
		testRelease = { cmd = "test", args = { "--release" } },
	},
})
assert(resolved.window_width == 0.5)
assert(resolved.commands.testRelease.cmd == "test")
assert(not pcall(config.resolve, { window_width = 2 }))
assert(not pcall(config.resolve, false))
assert(not pcall(config.resolve, { commands = { invalid = { nargs = 2 } } }))
assert(not pcall(config.resolve, { commands = { invalid = { args = { value = "--release" } } } }))

local cargo = require("cargo")
local opts = {
	auto_close = false,
	commands = {
		version = { cmd = "--version", nargs = 0, desc = "Show Cargo version" },
	},
}

-- setup() must replace plugin-owned commands and autocmds cleanly.
cargo.setup(opts)
local native = assert(package.loaded.cargo_nvim)
assert(type(native.cancel) == "function")
local cancelled_job = native.start("--version", {})
native.cancel(cancelled_job)
local cancelled_lines, cancelled_finished, cancelled_success = native.poll(cancelled_job)
assert(vim.deep_equal(cancelled_lines, {}))
assert(cancelled_finished)
assert(not cancelled_success)

assert(vim.fn.exists(":CargoVersion") == 2)
assert(vim.fn.exists(":CargoBuild") == 2)

cargo.setup({ auto_close = false })
assert(vim.fn.exists(":CargoVersion") == 0)
assert(vim.fn.exists(":CargoBuild") == 2)

cargo.setup(opts)
assert(vim.fn.exists(":CargoVersion") == 2)
assert(#vim.api.nvim_get_autocmds({
	group = "cargo.nvim",
	event = "FileType",
	pattern = "cargo-output",
}) == 1)
assert(#vim.api.nvim_get_autocmds({
	group = "cargo.nvim",
	event = "ColorScheme",
}) == 1)

vim.cmd.CargoVersion()
local bufnr = vim.api.nvim_get_current_buf()
assert(
	vim.wait(5000, function()
		return vim.b[bufnr].cargo_job_id == nil
	end, 10),
	"CargoVersion did not finish"
)

local output = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
assert(output:match("cargo %d+%.%d+%.%d+"), output)
assert(output:match("Command completed successfully"), output)

local close_mapping
for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
	if mapping.lhs == "q" then
		close_mapping = mapping
		break
	end
end
assert(close_mapping and close_mapping.desc == "Close cargo output")

local terminal_buf = cargo.run_in_terminal({ "--help" })
assert(vim.b[terminal_buf].cargo_terminal_job_id)
assert(
	vim.wait(5000, function()
		return vim.b[terminal_buf].cargo_terminal_job_id == nil
	end, 10),
	"CargoRunTerm did not finish"
)

local terminal_output = table.concat(vim.api.nvim_buf_get_lines(terminal_buf, 0, -1, false), "\n")
assert(terminal_output:match("Usage: cargo run"), terminal_output)
