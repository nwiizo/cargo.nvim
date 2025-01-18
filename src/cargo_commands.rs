// src/cargo_commands.rs
use mlua::prelude::*;
use std::process::Command;
use std::sync::Arc;
use tokio::runtime::Runtime;

/// Structure for handling Cargo commands
/// Contains a runtime for async operations
#[derive(Clone)]
pub struct CargoCommands {
    runtime: Arc<Runtime>,
}

impl CargoCommands {
    /// Create a new CargoCommands instance
    pub fn new() -> LuaResult<Self> {
        Ok(Self {
            runtime: Arc::new(
                tokio::runtime::Builder::new_current_thread()
                    .enable_all()
                    .build()
                    .map_err(|e| LuaError::RuntimeError(e.to_string()))?,
            ),
        })
    }

    /// Executes a future on the runtime
    pub fn execute<F, T>(&self, future: F) -> T
    where
        F: std::future::Future<Output = T>,
    {
        self.runtime.block_on(future)
    }

    /// Execute a Cargo command with the given arguments
    #[cfg(not(test))]
    async fn execute_cargo_command(&self, command: &str, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command_internal(command, args).await
    }

    /// Execute a Cargo command with the given arguments (public for testing)
    #[cfg(test)]
    pub async fn execute_cargo_command(&self, command: &str, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command_internal(command, args).await
    }

    /// Internal implementation of execute_cargo_command
    async fn execute_cargo_command_internal(
        &self,
        command: &str,
        args: &[&str],
    ) -> LuaResult<String> {
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
    pub async fn cargo_bench(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("bench", args).await
    }

    /// Build the project
    pub async fn cargo_build(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("build", args).await
    }

    /// Clean the target directory
    pub async fn cargo_clean(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("clean", args).await
    }

    /// Generate documentation
    pub async fn cargo_doc(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("doc", args).await
    }

    /// Create a new package
    pub async fn cargo_new(&self, name: &str, args: &[&str]) -> LuaResult<String> {
        let mut full_args = vec![name];
        full_args.extend_from_slice(args);
        self.execute_cargo_command("new", &full_args).await
    }

    /// Run the project
    pub async fn cargo_run(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("run", args).await
    }

    /// Run the tests
    pub async fn cargo_test(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("test", args).await
    }

    /// Update dependencies
    pub async fn cargo_update(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("update", args).await
    }

    // Additional Cargo Commands

    /// Check the project for errors
    pub async fn cargo_check(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("check", args).await
    }

    /// Initialize a new package in an existing directory
    pub async fn cargo_init(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("init", args).await
    }

    /// Add dependencies to a manifest file
    pub async fn cargo_add(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("add", args).await
    }

    /// Remove dependencies from a manifest file
    pub async fn cargo_remove(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("remove", args).await
    }

    /// Format Rust code
    pub async fn cargo_fmt(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("fmt", args).await
    }

    /// Run the Clippy linter
    pub async fn cargo_clippy(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("clippy", args).await
    }

    /// Automatically fix lint warnings
    pub async fn cargo_fix(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("fix", args).await
    }

    /// Package and upload crate to registry
    pub async fn cargo_publish(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("publish", args).await
    }

    /// Install a Rust binary
    pub async fn cargo_install(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("install", args).await
    }

    /// Uninstall a Rust binary
    pub async fn cargo_uninstall(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("uninstall", args).await
    }

    /// Search packages in registry
    pub async fn cargo_search(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("search", args).await
    }

    /// Display dependency tree
    pub async fn cargo_tree(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("tree", args).await
    }

    /// Vendor all dependencies locally
    pub async fn cargo_vendor(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("vendor", args).await
    }

    /// Audit dependencies for security vulnerabilities
    pub async fn cargo_audit(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("audit", args).await
    }

    /// Show outdated dependencies
    pub async fn cargo_outdated(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("outdated", args).await
    }

    /// Get Cargo help
    pub async fn cargo_help(&self, args: &[&str]) -> LuaResult<String> {
        self.execute_cargo_command("help", args).await
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn setup_test_commands() -> CargoCommands {
        CargoCommands::new().unwrap()
    }

    #[test]
    fn test_cargo_command_execution() {
        let rt = tokio::runtime::Runtime::new().unwrap();
        let cargo_commands = setup_test_commands();

        let result = rt.block_on(async { cargo_commands.cargo_help(&[]).await });

        assert!(result.is_ok());
    }

    #[test]
    fn test_invalid_command() {
        let rt = tokio::runtime::Runtime::new().unwrap();
        let cargo_commands = setup_test_commands();

        let result =
            rt.block_on(async { cargo_commands.execute_cargo_command("invalid", &[]).await });

        assert!(result.is_err());
    }

    #[test]
    fn test_execute_method() {
        let cargo_commands = setup_test_commands();
        let result = cargo_commands.execute(async { Ok::<_, LuaError>("test".to_string()) });
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), "test");
    }
}
