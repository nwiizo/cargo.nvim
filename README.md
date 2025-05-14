# 🚀 cargo.nvim

[![Rust CI](https://github.com/nwiizo/cargo.nvim/actions/workflows/rust.yml/badge.svg)](https://github.com/nwiizo/cargo.nvim/actions/workflows/rust.yml)
[![Lua CI](https://github.com/nwiizo/cargo.nvim/actions/workflows/lua.yml/badge.svg)](https://github.com/nwiizo/cargo.nvim/actions/workflows/lua.yml)

---

📦 A Neovim plugin that provides seamless integration with Rust's Cargo commands. Execute Cargo commands directly from Neovim with a floating window interface.

![cargo.nvim demo](.github/cargo.nvim.gif)

## ✨ Features

- 🔧 Execute Cargo commands directly from Neovim
- 🪟 Real-time output in floating windows
- 🎨 Syntax highlighting for Cargo output
- ⚡ Asynchronous command execution
- 🔄 Auto-closing windows on command completion
- ⌨️ Easy keyboard shortcuts for window management

## contents

- [🚀 cargo.nvim](#-cargonvim)
  - [✨ Features](#-features)
  - [📥 Installation](#-installation)
    - [Using lazy.nvim](#using-lazynvim)
    - [Using packer.nvim](#using-packernvim)
  - [📋 Requirements](#-requirements)
  - [🛠️ Available Commands](#️-available-commands)
  - [⚙️ Configuration](#️-configuration)
  - [⌨️ Key Mappings](#️-key-mappings)
  - [👥 Contributing](#-contributing)
  - [📜 License](#-license)
  - [💝 Acknowledgements](#-acknowledgements)

## 📥 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "nwiizo/cargo.nvim",
  build = "cargo build --release",
  config = function()
    require("cargo").setup({
      float_window = true,
      window_width = 0.8,
      window_height = 0.8,
      border = "rounded",
      auto_close = true,
      close_timeout = 5000,
    })
  end,
  ft = { "rust" },
  cmd = {
    "CargoBench",
    "CargoBuild", 
    "CargoClean",
    "CargoDoc",
    "CargoNew",
    "CargoRun",
    "CargoTest",
    "CargoUpdate"
  }
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "nwiizo/cargo.nvim",
  run = "cargo build --release",
  config = function()
    require("cargo").setup({
      float_window = true,
      window_width = 0.8,
      window_height = 0.8,
      border = "rounded",
      auto_close = true,
      close_timeout = 5000,
    })
  end,
}
```

## 📋 Requirements

- 💻 Neovim >= 0.9.0
- 🦀 Rust and Cargo installed on your system
- 📚 Additional dependencies:
  - **Ubuntu/Debian:** `libluajit-5.1-dev` (Install with `sudo apt install libluajit-5.1-dev`)
  - For other Linux distributions, you may need to install an equivalent LuaJIT development package

If you encounter build errors mentioning `lluajit-5.1` during installation, you likely need to install the LuaJIT development package for your system.

## 🛠️ Available Commands

- 📊 `:CargoBench` - Run benchmarks
- 🏗️ `:CargoBuild` - Build the project
- 🧹 `:CargoClean` - Remove generated artifacts 
- 📚 `:CargoDoc` - Generate project documentation
- ✨ `:CargoNew` - Create a new Cargo project
- ▶️  `:CargoRun` - Run the project
- 🧪 `:CargoTest` - Run tests
- 🔄 `:CargoUpdate` - Update dependencies
- 🤖 `:CargoAutodd` - Automatically manage dependencies

## ⚙️ Configuration

You can customize cargo.nvim by passing options to the setup function:

```lua
require("cargo").setup({
  -- Window settings
  float_window = true,          -- Use floating window
  window_width = 0.8,           -- Window width (80% of editor width)
  window_height = 0.8,          -- Window height (80% of editor height)
  border = "rounded",           -- Border style ("none", "single", "double", "rounded")
  wrap_output = true,           -- Enable text wrapping in output window
  
  -- Auto-close settings
  auto_close = true,            -- Auto close window on success
  close_timeout = 5000,         -- Close window after 5000ms
  
  -- Timeout settings
  run_timeout = 60,             -- Timeout for cargo run in seconds
  interactive_timeout = 30,     -- Inactivity timeout for interactive mode
  force_smart_detection = true, -- Always use smart detection for interactive programs
  
  -- Command settings 
  commands = {
    bench = { nargs = "*" },    -- Command arguments configuration
    build = { nargs = "*" },
    clean = { nargs = "*" },
    doc = { nargs = "*" },
    new = { nargs = 1 },
    run = { nargs = "*" },
    test = { nargs = "*" },
    update = { nargs = "*" },
  }
})
```

## ⌨️ Key Mappings

In the floating window:
- `q` or `<Esc>` - Close the window
- `<C-c>` - Cancel the running command and close the window
- `w` - Toggle text wrapping (useful for long error messages)

## 🔄 Interactive Mode

For interactive programs (e.g., those requiring user input):
- An input field appears at the bottom of the window
- Enter your input and press Enter to send it to the program
- The window automatically closes after 30 seconds of inactivity (configurable)
- The timeout prevents hanging processes and memory leaks

## 👥 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. 🍴 Fork the repository
2. 🌿 Create a feature branch
3. ✍️ Commit your changes
4. 🚀 Push to the branch
5. 📫 Open a Pull Request

## 📜 License

MIT License - see the [LICENSE](LICENSE) file for details.

## 💝 Acknowledgements

This plugin is inspired by various Neovim plugins and the Rust community.

## 🎉 Related Projects

- [cargo-autodd](https://github.com/nwiizo/cargo-autodd)

-- CargoRunTerm command - Run cargo run in terminal mode
vim.api.nvim_create_user_command("CargoRunTerm", function(args)
    -- Save all modified buffers before executing command
    vim.cmd("wa")
    
    -- Set window size
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
        title = " Cargo Run Terminal ",
        title_pos = "center",
    })
    
    -- Set window options
    vim.api.nvim_win_set_option(winnr, "number", true)
    vim.api.nvim_win_set_option(winnr, "wrap", true)
    vim.api.nvim_win_set_option(winnr, "cursorline", true)
    
    -- Build command line
    local cmd = "cargo run"
    if args.args and args.args ~= "" then
        cmd = cmd .. " " .. args.args
    end
    
    -- Start terminal
    vim.fn.termopen(cmd, {
        on_exit = function(_, _, _)
            -- Display message when terminal exits
            vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
                "",
                "=== Process completed ===",
                "Press q or <Esc> to close this window"
            })
            
            -- Exit insert mode
            vim.cmd("stopinsert")
            
            -- Set keymappings for closing the window
            vim.api.nvim_buf_set_keymap(bufnr, "n", "q", ":q<CR>", {noremap = true, silent = true})
            vim.api.nvim_buf_set_keymap(bufnr, "n", "<Esc>", ":q<CR>", {noremap = true, silent = true})
        end
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
        silent = true
    })
    
    -- Exit mapping (Ctrl+C, Ctrl+D)
    vim.api.nvim_buf_set_keymap(bufnr, "t", "<C-c>", "<C-c>", {noremap = true})
    vim.api.nvim_buf_set_keymap(bufnr, "t", "<C-d>", "<C-d>", {noremap = true})
    
    -- Start terminal mode (enable input)
    vim.cmd("startinsert")
end, {
    nargs = "*",
    desc = "Run cargo in interactive terminal mode (for proconio etc.)",
    complete = function(ArgLead, CmdLine, CursorPos)
        -- Provide argument completion
        local completions = {
            "--release", "--bin", "--example", "--package", "--target"
        }
        
        local matches = {}
        for _, comp in ipairs(completions) do
            if comp:find(ArgLead, 1, true) == 1 then
                table.insert(matches, comp)
            end
        end
        
        return matches
    end
})
