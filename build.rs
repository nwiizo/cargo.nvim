use std::path::PathBuf;

fn main() {
    let homebrew_prefix = PathBuf::from("/opt/homebrew");

    println!(
        "cargo:rustc-link-search=native={}/lib",
        homebrew_prefix.display()
    );
    println!("cargo:rustc-link-search=native=/usr/local/lib");
    println!("cargo:rustc-link-search=native=/usr/lib");
    println!(
        "cargo:rustc-link-search=native={}/opt/luajit/lib",
        homebrew_prefix.display()
    );
    println!("cargo:rustc-link-lib=dylib=luajit-5.1");
    println!("cargo:rustc-env=MACOSX_DEPLOYMENT_TARGET=11.0");
    println!("cargo:rustc-env=CC=/usr/bin/cc");
    println!("cargo:rerun-if-changed=build.rs");
}
