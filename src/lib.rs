// src/lib.rs
//! Neovim plugin for Cargo command integration.
//!
//! Bridges Neovim and Cargo: Lua starts a Cargo job through the exported API and
//! streams its output by polling. See [`job`] for the execution model.

mod job;
mod lua_exports;

/// Module entry point loaded by Neovim via `require("cargo_nvim")`.
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
        assert!(cargo_nvim(&lua).is_ok());
    }

    #[test]
    fn test_exported_functions() {
        let lua = Lua::new();
        let table = cargo_nvim(&lua).unwrap();
        assert!(table.get::<mlua::Function>("start").is_ok());
        assert!(table.get::<mlua::Function>("poll").is_ok());
        assert!(table.get::<mlua::Function>("send_input").is_ok());
        assert!(table.get::<mlua::Function>("interrupt").is_ok());
    }
}
