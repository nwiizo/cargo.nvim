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

        // Test essential commands are present
        assert!(table.contains_key("build").unwrap());
        assert!(table.contains_key("test").unwrap());
        assert!(table.contains_key("run").unwrap());
        assert!(table.contains_key("check").unwrap());
    }

    #[test]
    fn test_command_error_handling() {
        let lua = Lua::new();
        let table = cargo_nvim(&lua).unwrap();

        // Try to run a command with invalid arguments
        let result: mlua::Result<String> = table
            .get::<_, mlua::Function>("build")
            .unwrap()
            .call(vec!["--invalid-flag"]);

        assert!(result.is_err());
    }
}
