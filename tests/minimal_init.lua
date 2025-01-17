-- tests/minimal_init.lua
local plenary_dir = os.getenv("PLENARY_DIR") or "/home/runner/.local/share/nvim/site/pack/vendor/start/plenary.nvim"
local is_windows = vim.loop.os_uname().sysname == "Windows_NT"
local base_dir = vim.loop.cwd()

-- Add vim.inspect if it doesn't exist (needed for plenary)
if not vim.inspect then
	vim.inspect = require("vim.inspect")
end

-- Set up runtimepath
vim.cmd("set rtp+=" .. plenary_dir)
vim.cmd("set rtp+=" .. base_dir)
vim.cmd("runtime plugin/plenary.vim")
vim.cmd("runtime plugin/cargo.lua")

-- Set up lua path
local function join_paths(...)
	local result = table.concat({ ... }, "/")
	return is_windows and result:gsub("/", "\\") or result
end

local function normalize_path(path)
	return is_windows and path:gsub("\\", "/") or path
end

local lua_path = join_paths(base_dir, "lua")
package.path = normalize_path(lua_path) .. "/?.lua;" .. normalize_path(lua_path) .. "/?/init.lua;" .. package.path

-- Load required modules
require("plenary.busted")
