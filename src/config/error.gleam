//// Structured errors produced while loading, decoding, resolving, and
//// validating Arata configuration.
////
//// Configuration errors are kept separate from Markdown and frontmatter
//// errors because they refer to a different input boundary:
////
////   content/arata.toml
////
//// The configuration pipeline should preserve structured errors internally
//// and render them only at the build entry point. This allows tests and future
//// tooling to inspect error fields without parsing human-readable messages.
////
//// Missing fields may use built-in defaults. Present but invalid fields must
//// produce a configuration error instead of silently falling back.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// The stage at which a configuration error occurred.
pub type ConfigErrorKind {
  /// The configuration file could not be read.
  IoError

  /// The configuration file is not valid TOML.
  ParseError

  /// A TOML value could not be decoded into the expected configuration type.
  DecodeError

  /// A TOML table contains a key that Arata does not recognize.
  UnknownKeyError

  /// A decoded value violates a configuration invariant.
  ValidationError

  /// A referenced local asset is missing or invalid.
  AssetError
}

/// Optional source position reported by the TOML parser.
///
/// Line and column numbers are expected to be one-based when displayed to the
/// user. Parsers using zero-based positions must normalize them before
/// constructing this value.
pub type SourceLocation {
  SourceLocation(line: Int, column: Int)
}

/// A structured configuration diagnostic.
///
/// `section` and `key` are stored separately so callers can report either a
/// complete field path or a table-level error.
///
/// Examples:
///
///   section: Some("site")
///   key: Some("base_url")
///
/// renders as:
///
///   key: site.base_url
///
/// `expected` and `actual` are optional because I/O and TOML syntax errors may
/// not have meaningful typed values.
pub type ConfigError {
  ConfigError(
    kind: ConfigErrorKind,
    file: String,
    section: Option(String),
    key: Option(String),
    expected: Option(String),
    actual: Option(String),
    message: String,
    location: Option(SourceLocation),
  )
}

/// Construct an error for a configuration file that could not be read.
pub fn io(file: String, message: String) -> ConfigError {
  ConfigError(
    kind: IoError,
    file: file,
    section: None,
    key: None,
    expected: None,
    actual: None,
    message: message,
    location: None,
  )
}

/// Construct a TOML syntax error.
pub fn parse(
  file: String,
  message: String,
  location: Option(SourceLocation),
) -> ConfigError {
  ConfigError(
    kind: ParseError,
    file: file,
    section: None,
    key: None,
    expected: Some("valid TOML"),
    actual: None,
    message: message,
    location: location,
  )
}

/// Construct a decoding error for a field with an unexpected TOML type.
pub fn decode(
  file: String,
  section: Option(String),
  key: Option(String),
  expected: String,
  actual: String,
  message: String,
) -> ConfigError {
  ConfigError(
    kind: DecodeError,
    file: file,
    section: section,
    key: key,
    expected: Some(expected),
    actual: Some(actual),
    message: message,
    location: None,
  )
}

/// Construct an error for an unsupported key.
///
/// `key` should contain only the key name. The parent TOML table belongs in
/// `section`.
pub fn unknown_key(
  file: String,
  section: Option(String),
  key: String,
  message: String,
) -> ConfigError {
  ConfigError(
    kind: UnknownKeyError,
    file: file,
    section: section,
    key: Some(key),
    expected: Some("a supported configuration key"),
    actual: Some(key),
    message: message,
    location: None,
  )
}

/// Construct a semantic validation error.
///
/// Use this after TOML decoding succeeds but the resulting value violates an
/// Arata configuration invariant.
pub fn validation(
  file: String,
  section: Option(String),
  key: Option(String),
  expected: Option(String),
  actual: Option(String),
  message: String,
) -> ConfigError {
  ConfigError(
    kind: ValidationError,
    file: file,
    section: section,
    key: key,
    expected: expected,
    actual: actual,
    message: message,
    location: None,
  )
}

/// Construct an error for a missing or invalid local asset.
pub fn asset(
  file: String,
  section: Option(String),
  key: Option(String),
  path: String,
  message: String,
) -> ConfigError {
  ConfigError(
    kind: AssetError,
    file: file,
    section: section,
    key: key,
    expected: Some("an existing readable asset"),
    actual: Some(path),
    message: message,
    location: None,
  )
}

/// Attach a source location to an existing error.
pub fn with_location(
  error: ConfigError,
  line: Int,
  column: Int,
) -> ConfigError {
  ConfigError(
    ..error,
    location: Some(SourceLocation(line: line, column: column)),
  )
}

/// Return the dotted configuration path associated with an error.
///
/// Examples:
///
///   section = Some("site"), key = Some("title") -> Some("site.title")
///   section = Some("site"), key = None          -> Some("site")
///   section = None, key = Some("title")         -> Some("title")
///   section = None, key = None                  -> None
pub fn field_path(error: ConfigError) -> Option(String) {
  case error.section, error.key {
    Some(section), Some(key) -> Some(section <> "." <> key)
    Some(section), None -> Some(section)
    None, Some(key) -> Some(key)
    None, None -> None
  }
}

/// Return a stable machine-readable label for an error kind.
pub fn kind_name(kind: ConfigErrorKind) -> String {
  case kind {
    IoError -> "io"
    ParseError -> "parse"
    DecodeError -> "decode"
    UnknownKeyError -> "unknown-key"
    ValidationError -> "validation"
    AssetError -> "asset"
  }
}

/// Render one configuration error for build output.
///
/// The rendered format is intentionally stable and line-oriented:
///
///   error: invalid configuration value
///
///   file: content/arata.toml
///   key: latest_posts.count
///   expected: a non-negative integer
///   actual: -3
///   kind: validation
pub fn render(error: ConfigError) -> String {
  let details = [
    Some("file: " <> render_file_location(error.file, error.location)),
    render_optional_detail("key", field_path(error)),
    render_optional_detail("expected", error.expected),
    render_optional_detail("actual", error.actual),
    Some("kind: " <> kind_name(error.kind)),
  ]

  let rendered_details =
    details
    |> list.filter_map(fn(detail) { detail })
    |> string.join("\n")

  "error: " <> error.message <> "\n\n" <> rendered_details
}

/// Render multiple configuration errors as one build diagnostic.
///
/// Validation may return several independent errors so users can correct them
/// in one pass. Each diagnostic is separated by a blank line.
pub fn render_all(errors: List(ConfigError)) -> String {
  case errors {
    [] -> "error: configuration failed without a diagnostic"

    _ ->
      errors
      |> list.map(render)
      |> string.join("\n\n")
  }
}

fn render_optional_detail(
  label: String,
  value: Option(String),
) -> Option(String) {
  case value {
    Some(value) -> Some(label <> ": " <> value)
    None -> None
  }
}

fn render_file_location(
  file: String,
  location: Option(SourceLocation),
) -> String {
  case location {
    Some(SourceLocation(line:, column:)) ->
      file <> ":" <> int.to_string(line) <> ":" <> int.to_string(column)

    None -> file
  }
}
