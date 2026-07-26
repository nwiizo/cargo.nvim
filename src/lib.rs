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
