//! Lua-facing surface of the plugin.
//!
//! Exposes a small job API to Lua. Command execution is generic: Lua passes the
//! Cargo subcommand name and its arguments, so any `cargo` subcommand can be run
//! from configuration alone without a matching Rust function.

use crate::job;
use mlua::prelude::*;

pub fn register_commands(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;

    // start(subcommand, args) -> job_id
    exports.set(
        "start",
        lua.create_function(|_, (subcommand, args): (String, Option<Vec<String>>)| {
            Ok(job::start(subcommand, args.unwrap_or_default()))
        })?,
    )?;

    // poll(job_id) -> (lines, finished, success)
    exports.set("poll", lua.create_function(|_, id: u64| Ok(job::poll(id)))?)?;

    // send_input(job_id, input)
    exports.set(
        "send_input",
        lua.create_function(|_, (id, input): (u64, String)| {
            job::send_input(id, input);
            Ok(())
        })?,
    )?;

    // interrupt(job_id)
    exports.set(
        "interrupt",
        lua.create_function(|_, id: u64| {
            job::interrupt(id);
            Ok(())
        })?,
    )?;

    // cancel(job_id)
    exports.set(
        "cancel",
        lua.create_function(|_, id: u64| {
            job::cancel(id);
            Ok(())
        })?,
    )?;

    Ok(exports)
}
