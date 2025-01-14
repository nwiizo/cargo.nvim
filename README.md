# cargo.nvim

A Neovim plugin that provides seamless integration with Rust's Cargo commands. Execute Cargo commands directly from Neovim with a floating window interface.

## Features

- Execute Cargo commands directly from Neovim
- Real-time output in floating windows
- Syntax highlighting for Cargo output
- Asynchronous command execution
- Auto-closing windows on command completion
- Easy keyboard shortcuts for window management

## Installation

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

## Requirements

- Neovim >= 0.9.0
- Rust and Cargo installed on your system

## Available Commands

- `:CargoBench` - Run benchmarks
- `:CargoBuild` - Build the project
- `:CargoClean` - Remove generated artifacts 
- `:CargoDoc` - Generate project documentation
- `:CargoNew` - Create a new Cargo project
- `:CargoRun` - Run the project
- `:CargoTest` - Run tests
- `:CargoUpdate` - Update dependencies

## Configuration

You can customize cargo.nvim by passing options to the setup function:

```lua
require("cargo").setup({
  -- Window settings
  float_window = true,          -- Use floating window
  window_width = 0.8,           -- Window width (80% of editor width)
  window_height = 0.8,          -- Window height (80% of editor height)
  border = "rounded",           -- Border style ("none", "single", "double", "rounded")
  
  -- Auto-close settings
  auto_close = true,            -- Auto close window on success
  close_timeout = 5000,         -- Close window after 5000ms
  
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

## Key Mappings

In the floating window:
- `q` or `<Esc>` - Close the window
- `<C-c>` - Cancel the running command and close the window

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## License

MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgements

This plugin is inspired by various Neovim plugins and the Rust community.
