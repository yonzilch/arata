//// Tests for browser-safe runtime configuration projection and encoding.
////
//// These tests verify that resolved build configuration is projected into the
//// runtime model without drift and serialized with explicit provider
//// discriminators.

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
