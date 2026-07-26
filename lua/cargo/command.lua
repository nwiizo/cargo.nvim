local M = {}

function M.user_command_name(subcommand)
	return "Cargo" .. subcommand:sub(1, 1):upper() .. subcommand:sub(2)
end

function M.merge_args(preset_args, user_args)
	local args = {}

	for _, arg in ipairs(preset_args or {}) do
		args[#args + 1] = arg
	end
	for _, arg in ipairs(user_args or {}) do
		args[#args + 1] = arg
	end

	return args
end

function M.cargo_argv(subcommand, args)
	return M.merge_args({ "cargo", subcommand }, args)
end

return M
