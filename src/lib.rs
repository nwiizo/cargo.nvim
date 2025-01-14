use mlua::prelude::*;
use std::process::Command;
use std::sync::Arc;
use tokio::runtime::Runtime;

#[derive(Clone)]
struct CargoCommands {
    runtime: Arc<Runtime>,
}

impl CargoCommands {
    fn new() -> LuaResult<Self> {
        Ok(Self {
            runtime: Arc::new(
                tokio::runtime::Builder::new_current_thread()
                    .enable_all()
                    .build()
                    .map_err(|e| LuaError::RuntimeError(e.to_string()))?,
            ),
        })
    }

    async fn execute_cargo_command(&self, command: &str, args: &[&str]) -> LuaResult<String> {
        let mut cmd = Command::new("cargo");
        cmd.arg(command);
        cmd.args(args);

        let output = cmd.output().map_err(|e| {
            LuaError::RuntimeError(format!("Failed to execute cargo {}: {}", command, e))
        })?;

        if !output.status.success() {
            let error = String::from_utf8_lossy(&output.stderr);
            return Err(LuaError::RuntimeError(format!(
                "cargo {} failed: {}",
                command, error
            )));
        }

        Ok(String::from_utf8_lossy(&output.stdout).into_owned())
    }

    // Cargo commands implementation
    async fn cargo_bench(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("bench", args).await
    }

    async fn cargo_build(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("build", args).await
    }

    async fn cargo_clean(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("clean", args).await
    }

    async fn cargo_doc(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("doc", args).await
    }

    async fn cargo_new(&self, name: &str, args: &[&str]) -> LuaResult<String> {
        let mut full_args = vec![name];
        full_args.extend_from_slice(args);
        self.execute_cargo_command("new", &full_args).await
    }

    async fn cargo_run(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("run", args).await
    }

    async fn cargo_test(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("test", args).await
    }

    async fn cargo_update(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("update", args).await
    }
}

#[mlua::lua_module]
fn cargo_nvim(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;
    let cargo_commands = CargoCommands::new()?;

    // Export bench command
    let bench_cmd = {
        let cargo_commands = cargo_commands.clone();
        lua.create_function(move |_, args: Option<Vec<String>>| {
            let runtime = cargo_commands.runtime.clone();
            let args = args.unwrap_or_default();
            let args_ref: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
            runtime.block_on(async { cargo_commands.cargo_bench(&args_ref).await })
        })?
    };

    // Export build command
    let build_cmd = {
        let cargo_commands = cargo_commands.clone();
        lua.create_function(move |_, args: Option<Vec<String>>| {
            let runtime = cargo_commands.runtime.clone();
            let args = args.unwrap_or_default();
            let args_ref: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
            runtime.block_on(async { cargo_commands.cargo_build(&args_ref).await })
        })?
    };

    // Export clean command
    let clean_cmd = {
        let cargo_commands = cargo_commands.clone();
        lua.create_function(move |_, args: Option<Vec<String>>| {
            let runtime = cargo_commands.runtime.clone();
            let args = args.unwrap_or_default();
            let args_ref: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
            runtime.block_on(async { cargo_commands.cargo_clean(&args_ref).await })
        })?
    };

    // Export doc command
    let doc_cmd = {
        let cargo_commands = cargo_commands.clone();
        lua.create_function(move |_, args: Option<Vec<String>>| {
            let runtime = cargo_commands.runtime.clone();
            let args = args.unwrap_or_default();
            let args_ref: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
            runtime.block_on(async { cargo_commands.cargo_doc(&args_ref).await })
        })?
    };

    // Export new command
    let new_cmd = {
        let cargo_commands = cargo_commands.clone();
        lua.create_function(move |_, (name, args): (String, Option<Vec<String>>)| {
            let runtime = cargo_commands.runtime.clone();
            let args = args.unwrap_or_default();
            let args_ref: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
            runtime.block_on(async { cargo_commands.cargo_new(&name, &args_ref).await })
        })?
    };

    // Export run command
    let run_cmd = {
        let cargo_commands = cargo_commands.clone();
        lua.create_function(move |_, args: Option<Vec<String>>| {
            let runtime = cargo_commands.runtime.clone();
            let args = args.unwrap_or_default();
            let args_ref: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
            runtime.block_on(async { cargo_commands.cargo_run(&args_ref).await })
        })?
    };

    // Export test command
    let test_cmd = {
        let cargo_commands = cargo_commands.clone();
        lua.create_function(move |_, args: Option<Vec<String>>| {
            let runtime = cargo_commands.runtime.clone();
            let args = args.unwrap_or_default();
            let args_ref: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
            runtime.block_on(async { cargo_commands.cargo_test(&args_ref).await })
        })?
    };

    // Export update command
    let update_cmd = {
        let cargo_commands = cargo_commands.clone();
        lua.create_function(move |_, args: Option<Vec<String>>| {
            let runtime = cargo_commands.runtime.clone();
            let args = args.unwrap_or_default();
            let args_ref: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
            runtime.block_on(async { cargo_commands.cargo_update(&args_ref).await })
        })?
    };

    // Register all commands
    exports.set("bench", bench_cmd)?;
    exports.set("build", build_cmd)?;
    exports.set("clean", clean_cmd)?;
    exports.set("doc", doc_cmd)?;
    exports.set("new", new_cmd)?;
    exports.set("run", run_cmd)?;
    exports.set("test", test_cmd)?;
    exports.set("update", update_cmd)?;

    Ok(exports)
}
