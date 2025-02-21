// src/lua_exports.rs
use crate::CargoCommands;
use mlua::prelude::*;

pub fn register_commands(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;
    let cargo_commands = CargoCommands::new()?;

    // Define all available commands with their implementations
    let commands = vec![
        (
            "bench",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_bench(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "build",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_build(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "clean",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_clean(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "doc",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_doc(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "fmt",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_fmt(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "help",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_help(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "new",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async {
                    if let Some(name) = args.first() {
                        let remaining = &args[1..];
                        cmd.cargo_new(name, remaining).await
                    } else {
                        Err(LuaError::RuntimeError(
                            "Project name is required".to_string(),
                        ))
                    }
                })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "run",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_run(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "test",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_test(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "update",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_update(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "check",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_check(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "init",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_init(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "add",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_add(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "remove",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_remove(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "clippy",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_clippy(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "fix",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_fix(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "publish",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_publish(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "install",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_install(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "uninstall",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_uninstall(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "search",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_search(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "tree",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_tree(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "vendor",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_vendor(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "audit",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_audit(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "outdated",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_outdated(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
        (
            "autodd",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_autodd(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send>,
        ),
    ];

    // Register all commands to the Lua environment
    for (name, cmd_fn) in commands {
        let cargo_commands = cargo_commands.clone();
        let cmd = lua.create_function(move |_, args: Option<Vec<String>>| {
            let args = args.unwrap_or_default();
            let args_ref: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
            cmd_fn(&cargo_commands, &args_ref)
        })?;
        exports.set(name, cmd)?;
    }

    Ok(exports)
}

#[cfg(test)]
mod tests {
    use crate::cargo_nvim;
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

        assert!(table.contains_key("build").unwrap());
        assert!(table.contains_key("test").unwrap());
        assert!(table.contains_key("check").unwrap());
    }

    #[test]
    fn test_command_error_handling() {
        let lua = Lua::new();
        let table = cargo_nvim(&lua).unwrap();
        let build_fn: mlua::Function = table.get("build").unwrap();
        let result: mlua::Result<String> = build_fn.call(["--invalid-flag"]);
        assert!(result.is_err());
    }
}
