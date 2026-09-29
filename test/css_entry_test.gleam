//// Tests for the generated Bun CSS entry file.
////
//// `build/pipeline` writes a stylesheet that `@import`s every module in its
//// `css_modules` list, in cascade order, and hands that file to Bun. Three
//// things break the build if they regress, so they are asserted here:
////
////   - an `@import` whose URL no longer resolves, which makes Bun abort with
////     `Could not resolve`;
////   - a missing or duplicated `@import`, which silently drops a module or
////     double-applies its declarations;
////   - a reordered `@import`, which silently changes which rules win.

import build/pipeline
import gleam/list
import gleam/result
import gleam/string
import gleeunit
import gleeunit/should
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

/// The prefix every `@import` carries: one `../` per segment of the entry
/// directory (`build/dev/arata`).
///
/// Duplicated here on purpose. Moving the entry changes how every import
/// resolves, and this constant is where that coupling should become visible.
const entry_prefix = "../../../"

/// The project-relative module paths, in the cascade order the pipeline must
/// emit. The order is a documented requirement, not an implementation detail:
/// theme variables and global styles have to precede component styles, and
/// accessibility overrides have to stay last.
const expected_modules = [
  "src/css/fonts.css",
  "src/css/theme.css",
  "src/css/globals.css",
  "src/css/typography.css",
  "src/css/home.css",
  "src/css/aratafetch.css",
  "src/css/layout.css",
  "src/css/components.css",
  "src/css/pagination.css",
  "src/css/post.css",
  "src/css/cards.css",
  "src/css/links.css",
  "src/css/search.css",
  "src/css/toc.css",
  "src/css/syntax.css",
  "src/css/lightbox.css",
  "src/css/accessibility.css",
]

fn non_empty_lines(contents: String) -> List(String) {
  contents
  |> string.split("\n")
  |> list.filter(fn(line) { line != "" })
}

/// Extract the quoted URL from an `@import "…";` line.
fn import_url(line: String) -> String {
  line
  |> string.split("\"")
  |> list.drop(1)
  |> list.first
  |> result.unwrap(line)
}

fn import_urls() -> List(String) {
  pipeline.css_entry_contents()
  |> non_empty_lines
  |> list.map(import_url)
}

/// Drop the `../../../` prefix to recover the project-relative module path.
fn project_relative(url: String) -> String {
  string.replace(url, entry_prefix, "")
}

pub fn entry_imports_every_module_test() {
  import_urls()
  |> list.map(project_relative)
  |> should.equal(expected_modules)
}

pub fn entry_imports_resolve_to_real_files_test() {
  // The `@import` URLs are relative to the entry directory, so each one is
  // checked against the file it must ultimately point at.
  import_urls()
  |> list.each(fn(url) {
    url |> string.starts_with(entry_prefix) |> should.be_true

    url
    |> project_relative
    |> simplifile.read
    |> result.is_ok
    |> should.be_true
  })
}

pub fn entry_has_no_duplicate_imports_test() {
  let urls = import_urls()

  list.length(list.unique(urls))
  |> should.equal(list.length(urls))
}

pub fn entry_emits_one_import_per_line_test() {
  let lines = pipeline.css_entry_contents() |> non_empty_lines

  list.length(lines)
  |> should.equal(list.length(expected_modules))

  list.each(lines, fn(line) {
    line |> string.starts_with("@import ") |> should.be_true

    line |> string.ends_with("\";") |> should.be_true
  })
}
