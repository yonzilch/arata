//// Build-time loader for Arata's TOML configuration source.
////
//// The default user-owned configuration file is:
////
////   content/arata.toml
////
//// This module is responsible only for locating and reading configuration
//// source text. TOML decoding, default resolution, normalization, and semantic
//// validation belong to later configuration stages.
////
//// The default configuration file is optional for backward compatibility:
////
////   load()
////     -> Ok(None) when content/arata.toml does not exist
////     -> Ok(Some(source)) when it exists and is readable
////     -> Error(error) for every other file-system failure
////
//// An explicitly requested path is required:
////
////   load_required(path)
////     -> Error(error) when the path does not exist or cannot be read
////
//// Configuration must be loaded once by the build pipeline and passed to
//// downstream build stages. Other modules must not read this file directly.

import config/error.{type ConfigError}
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile.{type FileError, Enoent}

/// The only implicit configuration path supported by Arata.
///
/// Keeping this path centralized prevents different build modules from
/// resolving different configuration files.
pub const default_path = "content/arata.toml"

/// UTF-8 configuration source loaded from disk.
///
/// The path is preserved so decoding and validation errors can identify the
/// exact source file without depending on global configuration state.
pub type ConfigSource {
  ConfigSource(path: String, contents: String)
}

/// Load Arata's optional default configuration file.
///
/// A missing `content/arata.toml` is represented by `Ok(None)`, allowing the
/// resolver to use built-in defaults and preserving backward compatibility
/// with projects created before TOML configuration was introduced.
///
/// Any other read failure is returned as a structured configuration error.
pub fn load() -> Result(Option(ConfigSource), ConfigError) {
  load_optional(default_path)
}

/// Load an optional configuration file from a specific path.
///
/// This function is primarily useful for tests and controlled build tooling.
/// Application code should normally call `load()` so there is one canonical
/// implicit configuration path.
pub fn load_optional(
  path: String,
) -> Result(Option(ConfigSource), ConfigError) {
  case simplifile.read(path) {
    Ok(contents) -> Ok(Some(ConfigSource(path: path, contents: contents)))

    Error(Enoent) -> Ok(None)

    Error(file_error) -> Error(read_error(path, file_error))
  }
}

/// Load a required configuration file from a specific path.
///
/// Unlike `load()`, a missing file is an error. Use this when a path has been
/// explicitly selected by the caller, such as a future command-line option or
/// environment variable.
pub fn load_required(path: String) -> Result(ConfigSource, ConfigError) {
  simplifile.read(path)
  |> result.map(fn(contents) { ConfigSource(path: path, contents: contents) })
  |> result.map_error(fn(file_error) { read_error(path, file_error) })
}

/// Return the source path carried by a loaded configuration value.
pub fn path(source: ConfigSource) -> String {
  source.path
}

/// Return the UTF-8 TOML text carried by a loaded configuration value.
pub fn contents(source: ConfigSource) -> String {
  source.contents
}

fn read_error(path: String, file_error: FileError) -> ConfigError {
  let message = case file_error {
    Enoent -> "configuration file does not exist"

    _ -> "could not read configuration file: " <> string.inspect(file_error)
  }

  error.io(file: path, message: message)
}
