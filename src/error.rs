// src/error.rs
use std::fmt;

#[derive(Debug)]
pub enum Error {
    CommandFailed { command: String, details: String },
    RuntimeError(String),
    IoError(std::io::Error),
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Error::CommandFailed { command, details } => {
                write!(f, "Cargo command '{}' failed: {}", command, details)
            }
            Error::RuntimeError(msg) => write!(f, "Runtime error: {}", msg),
            Error::IoError(err) => write!(f, "IO error: {}", err),
        }
    }
}

impl std::error::Error for Error {}

impl From<std::io::Error> for Error {
    fn from(err: std::io::Error) -> Self {
        Error::IoError(err)
    }
}

impl From<Error> for mlua::Error {
    fn from(err: Error) -> Self {
        mlua::Error::RuntimeError(err.to_string())
    }
}
