//// Tests for canonical URL and deployment-path behavior.

import config/url
import gleeunit/should

pub fn canonical_base_url_trims_whitespace_test() {
  url.canonical_base_url("  https://example.com/blog  ")
  |> should.equal("https://example.com/blog")
}

pub fn canonical_base_url_removes_all_trailing_slashes_test() {
  url.canonical_base_url("https://example.com/blog///")
  |> should.equal("https://example.com/blog")
}

pub fn canonical_base_url_preserves_root_host_test() {
  url.canonical_base_url("https://example.com/")
  |> should.equal("https://example.com")
}

pub fn root_deployment_has_empty_base_path_test() {
  url.base_path_from_url("https://example.com")
  |> should.equal("")
}

pub fn root_deployment_with_trailing_slash_has_empty_base_path_test() {
  url.base_path_from_url("https://example.com/")
  |> should.equal("")
}

pub fn subdirectory_deployment_derives_base_path_test() {
  url.base_path_from_url("https://example.github.io/arata")
  |> should.equal("/arata")
}

pub fn nested_subdirectory_deployment_derives_base_path_test() {
  url.base_path_from_url("https://example.com/blog/docs/")
  |> should.equal("/blog/docs")
}

pub fn normalize_base_path_adds_leading_slash_test() {
  url.normalize_base_path("arata")
  |> should.equal("/arata")
}

pub fn normalize_base_path_removes_trailing_slashes_test() {
  url.normalize_base_path("/arata///")
  |> should.equal("/arata")
}

pub fn normalize_root_base_path_returns_empty_string_test() {
  url.normalize_base_path("/")
  |> should.equal("")
}

pub fn with_base_path_keeps_root_deployment_path_test() {
  url.with_base_path("", "/app.mjs")
  |> should.equal("/app.mjs")
}

pub fn with_base_path_prefixes_subdirectory_test() {
  url.with_base_path("/arata", "/app.mjs")
  |> should.equal("/arata/app.mjs")
}

pub fn with_base_path_preserves_subdirectory_root_slash_test() {
  url.with_base_path("/arata", "/")
  |> should.equal("/arata/")
}

pub fn resolve_site_url_prefixes_internal_path_test() {
  url.resolve_site_url("/arata", "/posts")
  |> should.equal("/arata/posts")
}

pub fn resolve_site_url_prefixes_path_without_leading_slash_test() {
  url.resolve_site_url("/arata", "images/logo.svg")
  |> should.equal("/arata/images/logo.svg")
}

pub fn resolve_site_url_preserves_https_url_test() {
  url.resolve_site_url("/arata", "https://example.com/resource.js")
  |> should.equal("https://example.com/resource.js")
}

pub fn resolve_site_url_preserves_protocol_relative_url_test() {
  url.resolve_site_url("/arata", "//cdn.example.com/resource.js")
  |> should.equal("//cdn.example.com/resource.js")
}

pub fn resolve_site_url_preserves_fragment_test() {
  url.resolve_site_url("/arata", "#comments")
  |> should.equal("#comments")
}

pub fn resolve_site_url_preserves_mailto_test() {
  url.resolve_site_url("/arata", "mailto:hello@example.com")
  |> should.equal("mailto:hello@example.com")
}

pub fn external_url_detection_is_case_insensitive_test() {
  url.is_external_or_special_url("HTTPS://EXAMPLE.COM/resource.js")
  |> should.equal(True)
}

pub fn site_local_url_rejects_empty_string_test() {
  url.is_site_local_url("")
  |> should.equal(False)
}

pub fn site_local_url_accepts_root_relative_path_test() {
  url.is_site_local_url("/posts")
  |> should.equal(True)
}

pub fn http_url_accepts_https_test() {
  url.is_http_url("https://example.com")
  |> should.equal(True)
}

pub fn http_url_rejects_ftp_test() {
  url.is_http_url("ftp://example.com")
  |> should.equal(False)
}
