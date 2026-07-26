package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

describe("cargo.command", function()
	local command = require("cargo.command")

	it("builds Neovim command names", function()
		assert.equals("CargoBuild", command.user_command_name("build"))
		assert.equals("CargoTestRelease", command.user_command_name("testRelease"))
	end)

	it("copies preset and user arguments in order", function()
		local preset = { "--release" }
		local user = { "--package", "my crate" }

		assert.same({ "--release", "--package", "my crate" }, command.merge_args(preset, user))
		assert.same({ "--release" }, preset)
		assert.same({ "--package", "my crate" }, user)
	end)

	it("builds an argv list without shell concatenation", function()
		assert.same(
			{ "cargo", "run", "--package", "my crate" },
			command.cargo_argv("run", {
				"--package",
				"my crate",
			})
		)
	end)
end)
