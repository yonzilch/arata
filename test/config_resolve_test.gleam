//// Tests for raw configuration resolution.
////
//// These tests verify default inheritance, explicit overrides, provider
//// construction, collection replacement, and deployment-path resolution.

import config/decoder
import config/loader
import config/resolve
import data/site.{AnalyticsDisabled, CommentsDisabled, Giscus, Umami}
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should

const fixture_dir = "test/fixtures/config"

pub fn empty_configuration_uses_built_in_defaults_test() {
  let resolved = resolve_fixture(fixture_dir <> "/empty.toml")

  let application = resolve.runtime_config(resolved)
  let metadata = resolve.site_meta(resolved)

  application.title
  |> should.equal("Arata")

  application.description
  |> should.equal("A modern and minimalistic blog theme")

  application.base_path
  |> should.equal("")

  application.rss_enabled
  |> should.equal(True)

  application.search_enabled
  |> should.equal(True)

  application.latest_posts_enabled
  |> should.equal(False)

  application.latest_posts_count
  |> should.equal(5)

  list.length(application.menu)
  |> should.equal(5)

  list.length(application.socials)
  |> should.equal(3)

  metadata.analytics
  |> should.equal(AnalyticsDisabled)

  metadata.comments
  |> should.equal(CommentsDisabled)
}

pub fn minimal_configuration_overrides_only_present_values_test() {
  let resolved = resolve_fixture(fixture_dir <> "/minimal.toml")

  let application = resolve.runtime_config(resolved)
  let metadata = resolve.site_meta(resolved)

  application.title
  |> should.equal("Minimal Arata")

  application.description
  |> should.equal("A modern and minimalistic blog theme")

  application.search_enabled
  |> should.equal(True)

  application.latest_posts_count
  |> should.equal(5)

  metadata.title
  |> should.equal("Minimal Arata")

  metadata.base_url
  |> should.equal("https://arata.yon.im")
}

pub fn full_configuration_resolves_all_supported_domains_test() {
  let resolved = resolve_fixture(fixture_dir <> "/full.toml")

  let application = resolve.runtime_config(resolved)
  let metadata = resolve.site_meta(resolved)

  application.title
  |> should.equal("Full Arata")

  application.description
  |> should.equal("A fully configured Arata test site")

  application.base_path
  |> should.equal("")

  application.logo
  |> should.equal(Some("/images/test-logo.svg"))

  application.favicon
  |> should.equal(Some("/images/test-favicon.svg"))

  application.navbar_fixed
  |> should.equal(False)

  application.sidebar_enabled
  |> should.equal(False)

  application.latest_posts_enabled
  |> should.equal(True)

  application.latest_posts_count
  |> should.equal(8)

  application.aratafetch_maintained_for
  |> should.equal(Some("since 2024-01-01"))

  application.fonts.text
  |> should.equal("\"Inter\", sans-serif")

  application.fonts.header
  |> should.equal("\"Space Grotesk\", sans-serif")

  application.fonts.code
  |> should.equal("\"JetBrains Mono\", monospace")

  application.analytics
  |> should.equal(Umami(
    website_id: "11111111-2222-3333-4444-555555555555",
    src: "https://analytics.example.com/script.js",
  ))

  metadata.comments
  |> should.equal(Giscus(
    repo: "example/arata",
    repo_id: "R_kgDOExample",
    category: "Announcements",
    category_id: "DIC_kwDOExample",
  ))

  metadata.fediverse_creator
  |> should.equal(Some("@arata@example.social"))

  list.length(application.menu)
  |> should.equal(3)

  // The two configured socials are preceded by the managed RSS social.
  list.length(application.socials)
  |> should.equal(3)

  let assert Ok(rss) = list.first(application.socials)

  rss.name
  |> should.equal("RSS")

  rss.url
  |> should.equal("/rss.xml")

  rss.icon
  |> should.equal("rss")
}

pub fn subdirectory_configuration_canonicalizes_and_prefixes_paths_test() {
  let resolved = resolve_fixture(fixture_dir <> "/subdirectory.toml")

  let application = resolve.runtime_config(resolved)
  let metadata = resolve.site_meta(resolved)

  metadata.base_url
  |> should.equal("https://example.github.io/arata")

  application.base_path
  |> should.equal("/arata")

  application.logo
  |> should.equal(Some("/arata/images/arata-logo.svg"))

  application.favicon
  |> should.equal(Some("/arata/images/arata-logo.avif"))

  let assert Ok(home) = list.first(application.menu)

  home.url
  |> should.equal("/arata/")

  application.mathjax_enabled
  |> should.equal(False)

  application.mathjax_cdn_url
  |> should.equal("/arata")

  application.aratafetch_maintained_for
  |> should.equal(None)
}

pub fn explicit_empty_collections_replace_default_collections_test() {
  let source =
    "
[site]
title = \"No Navigation\"

menu = []
socials = []

[features]
rss = false
"

  let assert Ok(raw) =
    decoder.decode_text("test/empty-collections.toml", source)

  let assert Ok(resolved) =
    resolve.resolve_from("test/empty-collections.toml", raw)

  let application = resolve.runtime_config(resolved)

  application.menu
  |> should.equal([])

  application.socials
  |> should.equal([])
}

pub fn unsupported_analytics_provider_fails_resolution_test() {
  let source =
    "
[analytics]
provider = \"unsupported\"
"

  let assert Ok(raw) =
    decoder.decode_text("test/unsupported-analytics.toml", source)

  resolve.resolve_from("test/unsupported-analytics.toml", raw)
  |> should.be_error
}

fn resolve_fixture(path: String) -> resolve.ResolvedConfig {
  let assert Ok(source) = loader.load_required(path)
  let assert Ok(raw) = decoder.decode(source)
  let assert Ok(resolved) = resolve.resolve_from(path, raw)

  resolved
}
