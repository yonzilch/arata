//// Tests for resolved configuration validation.
////
//// Validation operates after decoding and resolution. These tests therefore
//// construct resolved values through the production configuration pipeline
//// before checking semantic invariants.

import config/decoder
import config/error
import config/loader
import config/resolve
import config/validate
import gleam/list
import gleam/string
import gleeunit/should

const fixture_dir = "test/fixtures/config"

pub fn empty_configuration_is_valid_test() {
  let path = fixture_dir <> "/empty.toml"
  let resolved = resolve_fixture(path)

  validate.validate_from(path, resolved)
  |> should.be_ok
}

pub fn full_configuration_is_valid_test() {
  let path = fixture_dir <> "/full.toml"
  let resolved = resolve_fixture(path)

  validate.validate_from(path, resolved)
  |> should.be_ok
}

pub fn subdirectory_configuration_is_valid_test() {
  let path = fixture_dir <> "/subdirectory.toml"
  let resolved = resolve_fixture(path)

  validate.validate_from(path, resolved)
  |> should.be_ok
}

pub fn invalid_base_url_is_rejected_test() {
  let path = "test/invalid-base-url.toml"

  let source =
    "
[site]
base_url = \"ftp://example.com\"
"

  let resolved = resolve_text(path, source)

  validate.validate_from(path, resolved)
  |> should.be_error
}

pub fn base_url_query_and_fragment_are_rejected_test() {
  let path = "test/base-url-suffix.toml"

  let source =
    "
[site]
base_url = \"https://example.com/blog?preview=true#content\"
"

  let resolved = resolve_text(path, source)

  let assert Error(errors) = validate.validate_from(path, resolved)

  let has_multiple_errors = list.length(errors) >= 2

  has_multiple_errors
  |> should.equal(True)

  let rendered = error.render_all(errors)

  rendered
  |> string.contains("query string")
  |> should.equal(True)

  rendered
  |> string.contains("fragment")
  |> should.equal(True)
}

pub fn negative_latest_posts_count_is_rejected_test() {
  let path = "test/negative-latest-posts.toml"

  let source =
    "
[latest_posts]
count = -3
"

  let resolved = resolve_text(path, source)

  let assert Error(errors) = validate.validate_from(path, resolved)

  let rendered = error.render_all(errors)

  rendered
  |> string.contains("latest_posts.count")
  |> should.equal(True)

  rendered
  |> string.contains("non-negative integer")
  |> should.equal(True)
}

pub fn empty_site_title_is_rejected_test() {
  let path = "test/empty-title.toml"

  let source =
    "
[site]
title = \"\"
"

  let resolved = resolve_text(path, source)

  let assert Error(errors) = validate.validate_from(path, resolved)

  error.render_all(errors)
  |> string.contains("site.title")
  |> should.equal(True)
}

pub fn enabled_mathjax_requires_runtime_asset_test() {
  let path = "test/missing-mathjax-asset.toml"

  let source =
    "
[features]
mathjax = true

[assets]
mathjax_url = \"\"
"

  let resolved = resolve_text(path, source)

  let assert Error(errors) = validate.validate_from(path, resolved)

  let rendered = error.render_all(errors)

  rendered
  |> string.contains("assets.mathjax_url")
  |> should.equal(True)

  rendered
  |> string.contains("enabled")
  |> should.equal(True)
}

pub fn disabled_mathjax_allows_empty_runtime_asset_test() {
  let path = "test/disabled-mathjax.toml"

  let source =
    "
[features]
mathjax = false

[assets]
mathjax_url = \"\"
"

  let resolved = resolve_text(path, source)

  validate.validate_from(path, resolved)
  |> should.be_ok
}

pub fn invalid_navigation_url_is_rejected_test() {
  let path = "test/invalid-navigation-url.toml"

  let source =
    "
[[menu]]
name = \"posts\"
url = \"javascript:alert(1)\"
"

  let resolved = resolve_text(path, source)

  let assert Error(errors) = validate.validate_from(path, resolved)

  error.render_all(errors)
  |> string.contains("unsupported URL form")
  |> should.equal(True)
}

pub fn social_icon_with_extension_is_rejected_test() {
  let path = "test/social-icon-extension.toml"

  let source =
    "
[features]
rss = false

[[socials]]
name = \"GitHub\"
url = \"https://github.com/example/arata\"
icon = \"github.svg\"
"

  let resolved = resolve_text(path, source)

  let assert Error(errors) = validate.validate_from(path, resolved)

  error.render_all(errors)
  |> string.contains("must not include a file extension")
  |> should.equal(True)
}

pub fn social_icon_path_traversal_is_rejected_test() {
  let path = "test/social-icon-path.toml"

  let source =
    "
[features]
rss = false

[[socials]]
name = \"GitHub\"
url = \"https://github.com/example/arata\"
icon = \"../github\"
"

  let resolved = resolve_text(path, source)

  let assert Error(errors) = validate.validate_from(path, resolved)

  error.render_all(errors)
  |> string.contains("path separators")
  |> should.equal(True)
}

pub fn invalid_comments_repository_is_rejected_test() {
  let path = "test/invalid-comments-repository.toml"

  let source =
    "
[comments]
provider = \"utterances\"
repo = \"invalid-repository\"
"

  let resolved = resolve_text(path, source)

  let assert Error(errors) = validate.validate_from(path, resolved)

  error.render_all(errors)
  |> string.contains("owner/name")
  |> should.equal(True)
}

pub fn validation_collects_independent_errors_test() {
  let path = "test/multiple-validation-errors.toml"

  let source =
    "
[site]
base_url = \"ftp://example.com?preview=true#content\"
title = \"\"

[latest_posts]
count = -1

[fonts]
text = \"\"
header = \"\"
code = \"\"
"

  let resolved = resolve_text(path, source)

  let assert Error(errors) = validate.validate_from(path, resolved)

  let has_multiple_errors = list.length(errors) >= 7

  has_multiple_errors
  |> should.equal(True)
}

fn resolve_fixture(path: String) -> resolve.ResolvedConfig {
  let assert Ok(source) = loader.load_required(path)

  let assert Ok(raw) = decoder.decode(source)

  let assert Ok(resolved) = resolve.resolve_from(path, raw)

  resolved
}

fn resolve_text(path: String, source: String) -> resolve.ResolvedConfig {
  let assert Ok(raw) = decoder.decode_text(path, source)

  let assert Ok(resolved) = resolve.resolve_from(path, raw)

  resolved
}
