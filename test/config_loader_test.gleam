//// Tests for configuration source loading.
////
//// These tests verify file-system behavior only. TOML parsing and semantic
//// validation are covered by their respective configuration tests.

import config/loader
import gleam/option
import gleam/string
import gleeunit/should

const fixture_dir = "test/fixtures/config"

pub fn load_required_reads_configuration_source_test() {
  let path = fixture_dir <> "/minimal.toml"
  let assert Ok(source) = loader.load_required(path)

  loader.path(source)
  |> should.equal(path)

  loader.contents(source)
  |> string.contains("[site]")
  |> should.equal(True)

  loader.contents(source)
  |> string.contains("Minimal Arata")
  |> should.equal(True)
}

pub fn load_required_preserves_empty_file_test() {
  let path = fixture_dir <> "/empty.toml"
  let assert Ok(source) = loader.load_required(path)

  loader.path(source)
  |> should.equal(path)

  loader.contents(source)
  |> should.equal("")
}

pub fn load_optional_returns_none_for_missing_file_test() {
  let path = fixture_dir <> "/does-not-exist.toml"
  let assert Ok(result) = loader.load_optional(path)

  result
  |> should.equal(option.None)
}

pub fn load_required_fails_for_missing_file_test() {
  let path = fixture_dir <> "/does-not-exist.toml"

  loader.load_required(path)
  |> should.be_error
}

pub fn default_configuration_path_is_content_owned_test() {
  loader.default_path
  |> should.equal("content/arata.toml")
}
