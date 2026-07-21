//// URL and deployment-path normalization for Arata configuration.
////
//// This module owns the path invariants shared by configuration resolution,
//// generated build output, and runtime navigation.
////
//// The public site URL is the single source of truth for deployment location:
////
////   https://example.com
////     -> base path ""
////
////   https://example.com/arata
////     -> base path "/arata"
////
//// Users must not configure `base_path` independently. It is always derived
//// from the canonical `base_url`.
////
//// This module performs structural normalization only. Semantic validation,
//// such as requiring an HTTP or HTTPS scheme or rejecting query strings in
//// `base_url`, belongs to `config/validate`.

import gleam/string

/// Canonicalize the public deployed site URL.
///
/// Leading and trailing whitespace is removed. All trailing slashes are
/// removed so equivalent configured values produce the same internal value.
///
/// Examples:
///
///   canonical_base_url("https://example.com")
///     -> "https://example.com"
///
///   canonical_base_url(" https://example.com/blog/ ")
///     -> "https://example.com/blog"
///
/// An empty value remains empty. Semantic validation is responsible for
/// rejecting it before configuration enters the build pipeline.
pub fn canonical_base_url(url: String) -> String {
  url
  |> string.trim
  |> trim_trailing_slashes
}

/// Derive the deployment base path from a public site URL.
///
/// The URL should normally be canonicalized before this function is called,
/// but this function canonicalizes its input defensively so direct callers
/// receive stable behavior.
///
/// Examples:
///
///   base_path_from_url("https://example.com")
///     -> ""
///
///   base_path_from_url("https://example.com/")
///     -> ""
///
///   base_path_from_url("https://user.github.io/arata")
///     -> "/arata"
///
///   base_path_from_url("https://example.com/blog/docs/")
///     -> "/blog/docs"
///
/// Inputs without a URL scheme are treated as paths. This preserves the
/// existing helper behavior while semantic validation remains responsible for
/// rejecting invalid public base URLs.
pub fn base_path_from_url(url: String) -> String {
  let cleaned = canonical_base_url(url)

  case string.split_once(cleaned, "://") {
    Ok(#(_scheme, authority_and_path)) ->
      base_path_from_authority(authority_and_path)

    Error(_) -> normalize_base_path(cleaned)
  }
}

/// Normalize a deployment base path.
///
/// Examples:
///
///   normalize_base_path("")
///     -> ""
///
///   normalize_base_path("/")
///     -> ""
///
///   normalize_base_path("arata")
///     -> "/arata"
///
///   normalize_base_path("/arata/")
///     -> "/arata"
///
///   normalize_base_path(" /blog/docs/// ")
///     -> "/blog/docs"
pub fn normalize_base_path(path: String) -> String {
  path
  |> string.trim
  |> ensure_leading_slash
  |> trim_trailing_slashes
  |> normalize_root_path
}

/// Prefix a site-local path with a normalized deployment base path.
///
/// This function is intended for root-relative or path-like site resources.
/// External and special URLs should be passed through `resolve_site_url`
/// instead.
///
/// Examples:
///
///   with_base_path("", "/app.mjs")
///     -> "/app.mjs"
///
///   with_base_path("/arata", "/app.mjs")
///     -> "/arata/app.mjs"
///
///   with_base_path("/arata/", "posts")
///     -> "/arata/posts"
///
///   with_base_path("/arata", "/")
///     -> "/arata/"
///
/// Calling this function repeatedly is not idempotent:
///
///   with_base_path("/arata", "/arata/posts")
///     -> "/arata/arata/posts"
///
/// Paths must therefore receive their deployment prefix exactly once at the
/// configuration resolution boundary.
pub fn with_base_path(base_path: String, path: String) -> String {
  let base_path = normalize_base_path(base_path)
  let path = string.trim(path)

  case base_path, path {
    "", _ -> ensure_leading_slash(path)

    _, "" -> base_path

    _, "/" -> base_path <> "/"

    _, _ -> base_path <> ensure_leading_slash(path)
  }
}

/// Resolve a configurable site URL against the deployment base path.
///
/// External URLs and browser-special URLs are returned unchanged. Site-local
/// paths receive the deployment base path exactly once.
///
/// Examples:
///
///   resolve_site_url("/arata", "/posts")
///     -> "/arata/posts"
///
///   resolve_site_url("/arata", "images/logo.svg")
///     -> "/arata/images/logo.svg"
///
///   resolve_site_url("/arata", "https://example.com")
///     -> "https://example.com"
///
///   resolve_site_url("/arata", "#comments")
///     -> "#comments"
pub fn resolve_site_url(base_path: String, url: String) -> String {
  let url = string.trim(url)

  case is_external_or_special_url(url) {
    True -> url
    False -> with_base_path(base_path, url)
  }
}

/// Return whether a URL must not receive Arata's deployment base path.
///
/// Recognized values include:
///
///   - HTTP and HTTPS URLs;
///   - protocol-relative URLs;
///   - fragment references;
///   - email links;
///   - telephone links;
///   - data URLs;
///   - blob URLs.
///
/// Scheme checks are case-insensitive. The original URL is not modified.
pub fn is_external_or_special_url(url: String) -> Bool {
  let normalized =
    url
    |> string.trim
    |> string.lowercase

  string.starts_with(normalized, "https://")
  || string.starts_with(normalized, "http://")
  || string.starts_with(normalized, "//")
  || string.starts_with(normalized, "#")
  || string.starts_with(normalized, "mailto:")
  || string.starts_with(normalized, "tel:")
  || string.starts_with(normalized, "data:")
  || string.starts_with(normalized, "blob:")
}

/// Return whether a URL is an absolute HTTP or HTTPS URL.
///
/// This helper performs a structural scheme check only. It does not prove that
/// the URL has a valid host or is otherwise suitable as `site.base_url`.
pub fn is_http_url(url: String) -> Bool {
  let normalized =
    url
    |> string.trim
    |> string.lowercase

  string.starts_with(normalized, "https://")
  || string.starts_with(normalized, "http://")
}

/// Return whether a configurable URL is site-local.
///
/// Empty strings are not considered local URLs because they represent missing
/// values and must be handled by resolution or validation.
///
/// Fragment-only references are considered special rather than local because
/// they must not receive a deployment prefix.
pub fn is_site_local_url(url: String) -> Bool {
  let url = string.trim(url)

  case url {
    "" -> False
    _ -> !is_external_or_special_url(url)
  }
}

fn base_path_from_authority(authority_and_path: String) -> String {
  case string.split_once(authority_and_path, "/") {
    Ok(#(_authority, path)) -> normalize_base_path("/" <> path)

    Error(_) -> ""
  }
}

fn ensure_leading_slash(path: String) -> String {
  case path {
    "" -> ""

    _ ->
      case string.starts_with(path, "/") {
        True -> path
        False -> "/" <> path
      }
  }
}

fn trim_trailing_slashes(value: String) -> String {
  case string.ends_with(value, "/") {
    False -> value

    True -> {
      let size = string.length(value)

      value
      |> string.slice(0, size - 1)
      |> trim_trailing_slashes
    }
  }
}

fn normalize_root_path(path: String) -> String {
  case path {
    "/" -> ""
    _ -> path
  }
}
