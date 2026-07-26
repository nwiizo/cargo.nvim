---
name: maintain-cargo-nvim
description: Maintain cargo.nvim's Rust native module, Lua/Neovim runtime, build configuration, tests, CI, dependencies, documentation, release tooling, and version metadata. Use when changing Cargo.toml, Cargo.lock, .cargo/config.toml, src/, lua/, plugin/, tests/, README.md compatibility or usage claims, Release.sh, GitHub workflows, Neovim compatibility, process execution or cancellation, native-module linking, dependency versions, or releases.
---

# Maintain cargo.nvim

Preserve the native-module ABI and supported editor/toolchain matrix while
keeping changes easy to validate in a real Neovim host.

## Inspect before editing

1. Read `AGENTS.md`, `Cargo.toml`, `.cargo/config.toml`, the affected source,
   and the relevant workflow.
2. Inspect `jj st` and `jj diff --stat`; preserve unrelated changes.
3. Re-check current official documentation before changing a library, Neovim
   API, GitHub Action, or compatibility claim. Do not assume versions in this
   skill are the latest.
4. Apply the required shell-command wrapper from higher-level instructions to
   every command.

## Manage the compatibility contract

- Keep Rust/Cargo 1.97, Edition 2024, and Neovim 0.9 as the default minimum
  versions.
- Allow an explicit compatibility or architecture change requested by the
  user. Update the manifest, runtime guards, README claims, CI coverage, and
  regression tests together; do not leave the old contract implied elsewhere.
- Distinguish a current implementation pattern from an invariant. A redesign
  may replace the implementation guidance below when it preserves the native
  ABI, command safety, lifecycle guarantees, and declared compatibility with
  equivalent tests.
- Treat the native ABI and mlua module mode as strong defaults, not absolute
  prohibitions. Change either only when the user explicitly requests that
  boundary, and include a loader/build migration plus cross-platform tests.

## Preserve native and command-safety invariants

### Rust and native module

- Keep `rust-version = "1.97"` and Edition 2024 unless compatibility is being
  changed intentionally. Keep `Cargo.lock` synchronized and use `--locked` in
  reproducible build and CI commands.
- Keep `mlua` in `module` mode. Neovim supplies the Lua symbols at runtime; do
  not add a `build.rs`, pkg-config lookup, or direct Lua/LuaJIT library link.
- Keep `unsafe_op_in_unsafe_fn` and `clippy::undocumented_unsafe_blocks`
  denied in `Cargo.toml`. Document the proof obligation for any necessary
  unsafe block. Add other Clippy lints individually; do not enable the complete
  `pedantic` or `restriction` groups.
- Preserve the macOS dynamic-lookup flags in `.cargo/config.toml`. Do not set a
  workflow-level `RUSTFLAGS`, because it overrides target rustflags from Cargo
  configuration.
- Treat `luajit` and `lua51` as mutually exclusive. Never validate with
  `--all-features`; run each feature configuration separately.
- Enable only the Tokio features used by the source.
- Spawn Cargo without a shell. Keep user arguments as `Vec<String>`/Lua lists.
- Terminate Cargo and its descendants as one process group on Unix and one Job
  Object on Windows. Await/reap the worker and retain a deterministic
  long-running cancellation test.

### Lua and Neovim

- While retaining Neovim 0.9 compatibility, guard APIs introduced or changed in
  later versions. The current implementation preserves the `vim.validate`
  compatibility path and uses `jobstart(..., { term = true })` only on Neovim
  0.11+, with `termopen` for 0.9/0.10.
- Keep `setup()` idempotent. Clear only plugin-owned commands and autocmds.
- Prefer the current named augroups, autocmd descriptions, `vim.keymap.set`,
  buffer-local Lua callbacks, and mapping descriptions.
- When preserving the current buffer lifecycle, configure plugin-owned buffers
  before setting `filetype`, then let the `FileType` event apply buffer-local
  syntax and options.
- Prefer highlight links to standard groups with `default = true` and restore
  them after `ColorScheme`.
- Use `args.fargs` and argv lists. Do not split or concatenate user input into a
  shell command.
- The current loader uses `package.loadlib` and caches the returned module.
  Test any replacement in Neovim. Do not instantiate a standalone `mlua::Lua`
  in Rust tests: module mode deliberately leaves host Lua symbols unresolved.

### CI and release

- Pin third-party GitHub Actions to immutable commit SHAs, disable checkout
  credentials when unused, set minimal permissions, and keep timeouts.
- Keep Rust checks for the minimum toolchain and stable. Run tests/builds on
  Linux, macOS, and Windows; run headless Neovim integration on supported CI
  hosts where Neovim is installed.
- Run Clippy and tests for the mutually exclusive `luajit` and `lua51`
  configurations separately.
- Keep the Linux integration leg pinned to Neovim 0.9.5 and exercise a current
  Neovim release on macOS.
- Keep workflow path filters synchronized with every file class a job validates.
  In particular, Rust integration coverage must react to both `lua/` and
  `plugin/` runtime changes.
- Run headless integration as
  `nvim --headless -u NONE -l tests/integration.lua`. Do not use
  `+lua dofile(...)`, which can hide Lua assertion failures behind a successful
  process exit.
- For a version bump, update both the package version in `Cargo.toml` and the
  root package entry in `Cargo.lock`. Do not create a tag or release unless the
  user explicitly requests it.

## Validate changes

Run the relevant subset while iterating, then run the full local suite before
publishing. The following are logical commands; prefix each one with the active
shell wrapper required by higher-level instructions:

```bash
cargo fmt --all -- --check
cargo clippy --locked --all-targets -- -D warnings
cargo clippy --locked --all-targets --no-default-features --features lua51 -- -D warnings
cargo test --locked
cargo +1.97.0 check --locked
cargo +1.97.0 check --locked --no-default-features --features lua51
cargo check --locked --no-default-features --features lua51
cargo test --locked --no-default-features --features lua51
cargo build --locked --release
stylua --check lua plugin tests
luacheck lua plugin tests
busted tests/command_spec.lua
nvim --headless -u NONE -l tests/integration.lua
actionlint .github/workflows/*.yml
git diff --cached --check
git diff --check
```

Treat the explicit Rust 1.97 check as required MSRV evidence. If that toolchain
is unavailable locally, require the CI MSRV job and report the local skip.

Record `nvim --version`. Run integration on Neovim 0.9 when that executable is
available. A newer-Neovim pass does not prove the minimum; when 0.9 is not
available locally, require the pinned Linux CI result as minimum-version
evidence.

On macOS, inspect the release artifact when native linking changes:

```bash
otool -L target/release/libcargo_nvim.dylib
```

Confirm that it does not link a Homebrew or system Lua/LuaJIT library.

Run `tests/command_spec.lua` with Busted when the local Lua installation is
healthy. The headless integration must still cover the command helper and the
actual native module in Neovim's LuaJIT host.

## Complete the task

- Reinspect `jj st`, the final diff, version metadata, and generated files.
- Report each command actually run and its observed result. Identify skipped
  platform checks explicitly.
- When asked to publish, use the repository's jj publishing skill. Confirm the
  final `main`/`main@origin` hash. Derive expected workflows from the changed
  paths and each workflow's path filters, then wait for those runs. If an
  expected run is absent, report it; do not manually dispatch a workflow unless
  the user authorized that external action.
