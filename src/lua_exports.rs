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

    Ok(exports)
}

#[cfg(test)]
mod tests {
    use crate::cargo_nvim;
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
        for name in ["start", "poll", "send_input", "interrupt"] {
            assert!(table.contains_key(name).unwrap(), "missing export: {name}");
        }
    }

    #[test]
    fn test_poll_unknown_job_reports_finished() {
        let lua = Lua::new();
        let table = cargo_nvim(&lua).unwrap();
        let poll: mlua::Function = table.get("poll").unwrap();
        let (lines, finished, success): (Vec<String>, bool, bool) =
            poll.call(9_999_999u64).unwrap();
        assert!(lines.is_empty());
        assert!(finished);
        assert!(!success);
    }
}
