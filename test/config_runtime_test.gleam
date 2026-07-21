//// Tests for browser-safe runtime configuration projection and encoding.
////
//// These tests verify that resolved build configuration is projected into the
//// runtime model without drift and serialized with explicit provider
//// discriminators.
////
//// The subdirectory tests protect the configuration side of the bootstrap
//// invariant:
////
////   content/arata.toml
////     -> ResolvedConfig.base_path
////     -> RuntimeConfig.application.base_path
////     -> content_index.json
////
//// Reading the generated HTML bootstrap metadata through the browser FFI is
//// outside this module's scope and belongs in a browser or build-pipeline
//// integration test.

import config/decoder
import config/encoder
import config/loader
import config/resolve
import config/runtime
import gleam/option
import gleam/string
import gleeunit/should

const fixture_dir = "test/fixtures/config"

pub fn runtime_projection_preserves_application_configuration_test() {
  let resolved = resolve_fixture(fixture_dir <> "/full.toml")

  let application =
    resolved
    |> runtime.from_resolved
    |> runtime.application

  application.title
  |> should.equal("Full Arata")

  application.latest_posts_enabled
  |> should.equal(True)

  application.latest_posts_count
  |> should.equal(8)

  application.mathjax_cdn_url
  |> should.equal("https://cdn.example.com/mathjax.js")

  application.mermaid_cdn_url
  |> should.equal("https://cdn.example.com/mermaid.mjs")

  application.syntax_highlight_cdn_url
  |> should.equal("https://cdn.example.com/highlight.js")
}

pub fn runtime_projection_preserves_public_site_metadata_test() {
  let resolved = resolve_fixture(fixture_dir <> "/full.toml")

  let site =
    resolved
    |> runtime.from_resolved
    |> runtime.site

  site.base_url
  |> should.equal("https://blog.example.com")

  site.fediverse_creator
  |> should.equal(option.Some("@arata@example.social"))
}

pub fn runtime_projection_preserves_subdirectory_base_path_test() {
  let resolved = resolve_fixture(fixture_dir <> "/subdirectory.toml")

  let runtime_config = runtime.from_resolved(resolved)

  let application = runtime.application(runtime_config)

  let site = runtime.site(runtime_config)

  application.base_path
  |> should.equal("/arata")

  site.base_url
  |> should.equal("https://example.github.io/arata")
}

pub fn runtime_projection_prefixes_subdirectory_application_paths_test() {
  let resolved = resolve_fixture(fixture_dir <> "/subdirectory.toml")

  let application =
    resolved
    |> runtime.from_resolved
    |> runtime.application

  application.logo
  |> should.equal(option.Some("/arata/images/arata-logo.svg"))

  application.favicon
  |> should.equal(option.Some("/arata/images/arata-logo.avif"))

  let assert [home, posts, projects] = application.menu

  home.url
  |> should.equal("/arata/")

  posts.url
  |> should.equal("/arata/posts")

  projects.url
  |> should.equal("/arata/projects")
}

pub fn runtime_projection_preserves_empty_disabled_asset_urls_test() {
  let resolved = resolve_fixture(fixture_dir <> "/subdirectory.toml")

  let application =
    resolved
    |> runtime.from_resolved
    |> runtime.application

  application.mathjax_enabled
  |> should.equal(False)

  application.mathjax_cdn_url
  |> should.equal("")

  application.mermaid_enabled
  |> should.equal(False)

  application.mermaid_cdn_url
  |> should.equal("")

  application.syntax_highlight_enabled
  |> should.equal(False)

  application.syntax_highlight_cdn_url
  |> should.equal("")
}

pub fn runtime_encoder_emits_application_and_site_sections_test() {
  let encoded =
    resolve_fixture(fixture_dir <> "/full.toml")
    |> runtime.from_resolved
    |> encoder.to_string

  encoded
  |> string.contains("\"application\"")
  |> should.equal(True)

  encoded
  |> string.contains("\"site\"")
  |> should.equal(True)

  encoded
  |> string.contains("\"title\":\"Full Arata\"")
  |> should.equal(True)

  encoded
  |> string.contains("\"base_url\":\"https://blog.example.com\"")
  |> should.equal(True)
}

pub fn runtime_encoder_emits_subdirectory_base_path_test() {
  let encoded =
    resolve_fixture(fixture_dir <> "/subdirectory.toml")
    |> runtime.from_resolved
    |> encoder.to_string

  encoded
  |> string.contains("\"base_path\":\"/arata\"")
  |> should.equal(True)

  encoded
  |> string.contains("\"base_url\":\"https://example.github.io/arata\"")
  |> should.equal(True)

  encoded
  |> string.contains("\"url\":\"/arata/posts\"")
  |> should.equal(True)

  encoded
  |> string.contains("\"favicon\":\"/arata/images/arata-logo.avif\"")
  |> should.equal(True)
}

pub fn runtime_encoder_does_not_duplicate_subdirectory_prefix_test() {
  let encoded =
    resolve_fixture(fixture_dir <> "/subdirectory.toml")
    |> runtime.from_resolved
    |> encoder.to_string

  encoded
  |> string.contains("/arata/arata/")
  |> should.equal(False)
}

pub fn runtime_encoder_preserves_empty_disabled_asset_urls_test() {
  let encoded =
    resolve_fixture(fixture_dir <> "/subdirectory.toml")
    |> runtime.from_resolved
    |> encoder.to_string

  encoded
  |> string.contains("\"mathjax_cdn_url\":\"\"")
  |> should.equal(True)

  encoded
  |> string.contains("\"mermaid_cdn_url\":\"\"")
  |> should.equal(True)

  encoded
  |> string.contains("\"syntax_highlight_cdn_url\":\"\"")
  |> should.equal(True)
}

pub fn runtime_encoder_emits_analytics_discriminator_test() {
  let encoded =
    resolve_fixture(fixture_dir <> "/full.toml")
    |> runtime.from_resolved
    |> encoder.to_string

  encoded
  |> string.contains("\"provider\":\"umami\"")
  |> should.equal(True)

  encoded
  |> string.contains("\"website_id\":\"11111111-2222-3333-4444-555555555555\"")
  |> should.equal(True)
}

pub fn runtime_encoder_emits_comments_discriminator_test() {
  let encoded =
    resolve_fixture(fixture_dir <> "/full.toml")
    |> runtime.from_resolved
    |> encoder.to_string

  encoded
  |> string.contains("\"provider\":\"giscus\"")
  |> should.equal(True)

  encoded
  |> string.contains("\"repo\":\"example/arata\"")
  |> should.equal(True)

  encoded
  |> string.contains("\"repo_id\":\"R_kgDOExample\"")
  |> should.equal(True)
}

pub fn runtime_encoder_emits_null_optional_values_test() {
  let encoded =
    resolve_fixture(fixture_dir <> "/empty.toml")
    |> runtime.from_resolved
    |> encoder.to_string

  encoded
  |> string.contains("\"logo\":null")
  |> should.equal(True)

  encoded
  |> string.contains("\"fediverse_creator\":null")
  |> should.equal(True)
}

fn resolve_fixture(path: String) -> resolve.ResolvedConfig {
  let assert Ok(source) = loader.load_required(path)

  let assert Ok(raw) = decoder.decode(source)

  let assert Ok(resolved) = resolve.resolve_from(path, raw)

  resolved
}
