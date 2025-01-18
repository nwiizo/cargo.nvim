// src/lib.rs
//! Neovim plugin for Cargo command integration
//! This module provides a bridge between Neovim and Cargo commands
//! allowing users to run Cargo commands directly from Neovim.

mod cargo_commands;
mod error;
mod lua_exports;

pub use cargo_commands::CargoCommands;
pub use error::Error;

/// Main module registration for Neovim
#[mlua::lua_module]
fn cargo_nvim(lua: &mlua::Lua) -> mlua::Result<mlua::Table> {
    lua_exports::register_commands(lua)
}

/// test module for Neovim
#[cfg(test)]
mod tests {
    use super::*;
    use mlua::Lua;

    #[test]
    fn test_module_registration() {
        let lua = Lua::new();
        let result = cargo_nvim(&lua);
        assert!(result.is_ok());
    }

    #[test]
    fn test_exported_commands() {
        let lua = Lua::new();
        let table = cargo_nvim(&lua).unwrap();

        // Fix: Remove unnecessary generic parameter and use correct type
        assert!(table.get::<mlua::Function>("build").is_ok());
        assert!(table.get::<mlua::Function>("test").is_ok());
        assert!(table.get::<mlua::Function>("check").is_ok());
    }

    #[test]
    fn test_command_error_handling() {
        let lua = Lua::new();
        let table = cargo_nvim(&lua).unwrap();

        // Fix: Remove unnecessary generic parameter and use correct type
        let build_fn = table.get::<mlua::Function>("build").unwrap();
        let result: mlua::Result<String> = build_fn.call(vec!["--invalid-flag"]);

        assert!(result.is_err());
    }
}
