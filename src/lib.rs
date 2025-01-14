// src/lib.rs
//! Neovim plugin for Cargo command integration
//! This module provides a bridge between Neovim and Cargo commands
//! allowing users to run Cargo commands directly from Neovim.

use mlua::prelude::*;
use std::process::Command;
use std::sync::Arc;
use tokio::runtime::Runtime;

/// Structure for handling Cargo commands
/// Contains a runtime for async operations
#[derive(Clone)]
struct CargoCommands {
    runtime: Arc<Runtime>,
}

impl CargoCommands {
    /// Create a new CargoCommands instance
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

    /// Execute a Cargo command with the given arguments
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

    // Basic Cargo Commands

    /// Run benchmarks
    async fn cargo_bench(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("bench", args).await
    }

    /// Build the project
    async fn cargo_build(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("build", args).await
    }

    /// Clean the target directory
    async fn cargo_clean(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("clean", args).await
    }

    /// Generate documentation
    async fn cargo_doc(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("doc", args).await
    }

    /// Create a new package
    async fn cargo_new(&self, name: &str, args: &[&str]) -> LuaResult<String> {
        let mut full_args = vec![name];
        full_args.extend_from_slice(args);
        self.execute_cargo_command("new", &full_args).await
    }

    /// Run the project
    async fn cargo_run(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("run", args).await
    }

    /// Run the tests
    async fn cargo_test(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("test", args).await
    }

    /// Update dependencies
    async fn cargo_update(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("update", args).await
    }

    // Additional Cargo Commands

    /// Check the project for errors
    async fn cargo_check(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("check", args).await
    }

    /// Initialize a new package in an existing directory
    async fn cargo_init(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("init", args).await
    }

    /// Add dependencies to a manifest file
    async fn cargo_add(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("add", args).await
    }

    /// Remove dependencies from a manifest file
    async fn cargo_remove(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("remove", args).await
    }

    /// Format Rust code
    async fn cargo_fmt(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("fmt", args).await
    }

    /// Run the Clippy linter
    async fn cargo_clippy(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("clippy", args).await
    }

    /// Automatically fix lint warnings
    async fn cargo_fix(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("fix", args).await
    }

    /// Package and upload crate to registry
    async fn cargo_publish(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("publish", args).await
    }

    /// Install a Rust binary
    async fn cargo_install(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("install", args).await
    }

    /// Uninstall a Rust binary
    async fn cargo_uninstall(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("uninstall", args).await
    }

    /// Search packages in registry
    async fn cargo_search(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("search", args).await
    }

    /// Display dependency tree
    async fn cargo_tree(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("tree", args).await
    }

    /// Vendor all dependencies locally
    async fn cargo_vendor(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("vendor", args).await
    }

    /// Audit dependencies for security vulnerabilities
    async fn cargo_audit(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("audit", args).await
    }

    /// Show outdated dependencies
    async fn cargo_outdated(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("outdated", args).await
    }
}

/// Main module registration for Neovim
#[mlua::lua_module]
fn cargo_nvim(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;
    let cargo_commands = CargoCommands::new()?;

    // Define all available commands with their implementations
    let commands: Vec<(
        &str,
        Box<dyn Fn(&CargoCommands, &[&str]) -> LuaResult<String> + Send + 'static>,
    )> = vec![
        // Basic commands
        (
            "bench",
            Box::new(|cmd, args| cmd.runtime.block_on(async { cmd.cargo_bench(args).await })),
        ),
        (
            "build",
            Box::new(|cmd, args| cmd.runtime.block_on(async { cmd.cargo_build(args).await })),
        ),
        (
            "clean",
            Box::new(|cmd, args| cmd.runtime.block_on(async { cmd.cargo_clean(args).await })),
        ),
        (
            "doc",
            Box::new(|cmd, args| cmd.runtime.block_on(async { cmd.cargo_doc(args).await })),
        ),
        (
            "new",
            Box::new(|cmd, args| {
                cmd.runtime.block_on(async {
                    if let Some(name) = args.first() {
                        let remaining = &args[1..];
                        cmd.cargo_new(name, remaining).await
                    } else {
                        Err(LuaError::RuntimeError(
                            "Project name is required".to_string(),
                        ))
                    }
                })
            }),
        ),
        (
            "run",
            Box::new(|cmd, args| cmd.runtime.block_on(async { cmd.cargo_run(args).await })),
        ),
        (
            "test",
            Box::new(|cmd, args| cmd.runtime.block_on(async { cmd.cargo_test(args).await })),
        ),
        (
            "update",
            Box::new(|cmd, args| cmd.runtime.block_on(async { cmd.cargo_update(args).await })),
        ),
        // Additional commands
        (
            "check",
            Box::new(|cmd, args| cmd.runtime.block_on(async { cmd.cargo_check(args).await })),
        ),
        (
            "init",
            Box::new(|cmd, args| cmd.runtime.block_on(async { cmd.cargo_init(args).await })),
        ),
        (
            "add",
            Box::new(|cmd, args| cmd.runtime.block_on(async { cmd.cargo_add(args).await })),
        ),
        (
            "remove",
            Box::new(|cmd, args| cmd.runtime.block_on(async { cmd.cargo_remove(args).await })),
        ),
        (
            "fmt",
            Box::new(|cmd, args| cmd.runtime.block_on(async { cmd.cargo_fmt(args).await })),
        ),
        (
            "clippy",
            Box::new(|cmd, args| cmd.runtime.block_on(async { cmd.cargo_clippy(args).await })),
        ),
        (
            "fix",
            Box::new(|cmd, args| cmd.runtime.block_on(async { cmd.cargo_fix(args).await })),
        ),
        (
            "publish",
            Box::new(|cmd, args| {
                cmd.runtime
                    .block_on(async { cmd.cargo_publish(args).await })
            }),
        ),
        (
            "install",
            Box::new(|cmd, args| {
                cmd.runtime
                    .block_on(async { cmd.cargo_install(args).await })
            }),
        ),
        (
            "uninstall",
            Box::new(|cmd, args| {
                cmd.runtime
                    .block_on(async { cmd.cargo_uninstall(args).await })
            }),
        ),
        (
            "search",
            Box::new(|cmd, args| cmd.runtime.block_on(async { cmd.cargo_search(args).await })),
        ),
        (
            "tree",
            Box::new(|cmd, args| cmd.runtime.block_on(async { cmd.cargo_tree(args).await })),
        ),
        (
            "vendor",
            Box::new(|cmd, args| cmd.runtime.block_on(async { cmd.cargo_vendor(args).await })),
        ),
        (
            "audit",
            Box::new(|cmd, args| cmd.runtime.block_on(async { cmd.cargo_audit(args).await })),
        ),
        (
            "outdated",
            Box::new(|cmd, args| {
                cmd.runtime
                    .block_on(async { cmd.cargo_outdated(args).await })
            }),
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
