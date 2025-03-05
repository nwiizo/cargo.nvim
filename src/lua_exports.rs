// src/lua_exports.rs
use crate::CargoCommands;
use mlua::prelude::*;
use std::sync::Mutex;
use tokio::sync::mpsc;

// 標準入力を送信するためのチャネル
static INPUT_SENDER: Mutex<Option<mpsc::Sender<String>>> = Mutex::new(None);

// 標準入力送信用のチャネルを設定
pub fn set_input_sender(sender: mpsc::Sender<String>) {
    let mut guard = INPUT_SENDER.lock().unwrap();
    *guard = Some(sender);
}

pub fn register_commands(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;
    let cargo_commands = CargoCommands::new()?;

    // Define all available commands with their implementations
    let commands = vec![
        (
            "bench",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_bench(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "build",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_build(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "clean",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_clean(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "doc",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_doc(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "fmt",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_fmt(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "help",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_help(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
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
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "run",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_run(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "test",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_test(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "update",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_update(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "check",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_check(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "init",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_init(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "add",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_add(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "remove",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_remove(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "clippy",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_clippy(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "fix",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_fix(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "publish",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_publish(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "install",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_install(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "uninstall",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_uninstall(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "search",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_search(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "tree",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_tree(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "vendor",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_vendor(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "audit",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_audit(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "outdated",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_outdated(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
        ),
        (
            "autodd",
            Box::new(move |cmd: &CargoCommands, args: &[&str]| {
                cmd.execute(async { cmd.cargo_autodd(args).await })
            }) as Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<(String, bool)> + Send>,
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

    // Register interrupt function
    let interrupt = lua.create_function(move |_, _: ()| {
        // TODO: Implement interrupt functionality
        Ok(())
    })?;
    exports.set("interrupt", interrupt)?;

    // Register send_input function for interactive mode
    let send_input = lua.create_function(move |_, input: String| {
        if let Some(sender) = INPUT_SENDER.lock().unwrap().as_ref() {
            // 非同期でメッセージを送信（エラーは無視）
            let _ = sender.try_send(input);
        }
        Ok(())
    })?;
    exports.set("send_input", send_input)?;

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
