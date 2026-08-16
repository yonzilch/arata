//// Tests for build-time heading processing (`content/headings.gleam`): the
//// Unicode-aware slug policy, document-scoped duplicate and fallback ID
//// assignment, determinism, and the invariant that every rendered heading and
//// every ToC target consume the same final ID.

import content/headings
import data/post.{type TocEntry, TocEntry}
import gleam/list
import gleam/string
import gleeunit
import gleeunit/should

pub fn main() -> Nil {
  gleeunit.main()
}

// SLUG POLICY ----------------------------------------------------------------

pub fn latin_heading_slugifies_to_readable_id_test() {
  headings.slugify("Hello World")
  |> should.equal("hello-world")
}

pub fn cjk_heading_is_preserved_test() {
  headings.slugify("安装指南")
  |> should.equal("安装指南")
}

pub fn mixed_language_heading_slug_test() {
  headings.slugify("Hello 世界")
  |> should.equal("hello-世界")
}

pub fn uppercase_latin_is_lowercased_test() {
  headings.slugify("HELLO WORLD")
  |> should.equal("hello-world")
}

pub fn ascii_punctuation_is_removed_test() {
  headings.slugify("Hello, World!")
  |> should.equal("hello-world")
}

pub fn cjk_punctuation_is_removed_test() {
  headings.slugify("安装，指南：如何开始？")
  |> should.equal("安装指南如何开始")
}

pub fn whitespace_normalizes_to_single_separator_test() {
  headings.slugify("  Hello   World  ")
  |> should.equal("hello-world")
}

pub fn hyphens_and_underscores_are_separators_test() {
  headings.slugify("Foo_Bar-Baz")
  |> should.equal("foo-bar-baz")
}

pub fn consecutive_separators_collapse_test() {
  headings.slugify("Foo -- Bar")
  |> should.equal("foo-bar")
}

pub fn leading_and_trailing_separators_are_trimmed_test() {
  headings.slugify("- Foo -")
  |> should.equal("foo")
}

pub fn punctuation_only_heading_has_no_usable_slug_test() {
  headings.slugify("!!!")
  |> should.equal("")
}

pub fn emoji_only_heading_has_no_usable_slug_test() {
  headings.slugify("😀")
  |> should.equal("")
}

pub fn emoji_inside_text_is_removed_from_slug_test() {
  headings.slugify("Hello 😀 World")
  |> should.equal("hello-world")
}

// ID ASSIGNMENT --------------------------------------------------------------

pub fn every_heading_receives_a_non_empty_id_test() {
  let html = "<h1>Title</h1><h2>Section</h2><h3>Sub</h3>"
  let #(out_html, _toc) = headings.process(html)

  out_html
  |> string.contains("id=\"title\"")
  |> should.equal(True)

  out_html
  |> string.contains("id=\"section\"")
  |> should.equal(True)

  out_html
  |> string.contains("id=\"sub\"")
  |> should.equal(True)
}

pub fn heading_ids_are_unique_within_a_document_test() {
  let html = "<h2>Foo</h2><h2>Foo</h2><h2>Foo 2</h2><h2>Bar</h2><h2>安装</h2>"
  let assigned_ids = ids(headings.assign_heading_ids(html))

  list.length(assigned_ids)
  |> should.equal(5)

  assigned_ids
  |> list.unique
  |> list.length
  |> should.equal(5)
}

pub fn duplicate_titles_get_numeric_suffixes_in_document_order_test() {
  headings.assign_heading_ids("<h2>Foo</h2><h2>Foo</h2><h2>Foo</h2>")
  |> ids
  |> should.equal(["foo", "foo-2", "foo-3"])
}

pub fn normalized_slug_collisions_get_suffixes_test() {
  let html = "<h2>Foo Bar</h2><h2>Foo-Bar</h2><h2>Foo_Bar</h2>"

  headings.assign_heading_ids(html)
  |> ids
  |> should.equal(["foo-bar", "foo-bar-2", "foo-bar-3"])
}

pub fn naturally_suffixed_titles_do_not_collide_test() {
  // "Foo 2" naturally slugifies to `foo-2`; the second "Foo" must be bumped
  // past it instead of colliding.
  let html = "<h2>Foo</h2><h2>Foo 2</h2><h2>Foo</h2>"

  headings.assign_heading_ids(html)
  |> ids
  |> should.equal(["foo", "foo-2", "foo-3"])
}

pub fn repeated_titles_after_natural_suffix_stay_unique_test() {
  let html = "<h2>Foo</h2><h2>Foo</h2><h2>Foo 2</h2><h2>Foo</h2>"

  headings.assign_heading_ids(html)
  |> ids
  |> should.equal(["foo", "foo-2", "foo-2-2", "foo-3"])
}

pub fn no_usable_slug_gets_sequential_fallback_ids_test() {
  let html = "<h2>!!!</h2><h2>😀</h2><h2>???</h2>"

  headings.assign_heading_ids(html)
  |> ids
  |> should.equal(["heading-1", "heading-2", "heading-3"])
}

pub fn fallback_ids_skip_naturally_taken_numbers_test() {
  // "Heading 1" naturally slugifies to `heading-1`, so the first fallback
  // must skip to `heading-2`.
  let html = "<h2>Heading 1</h2><h2>!!!</h2>"

  headings.assign_heading_ids(html)
  |> ids
  |> should.equal(["heading-1", "heading-2"])
}

pub fn fallback_numbering_is_scoped_to_the_current_document_test() {
  let first = headings.assign_heading_ids("<h2>!!!</h2>")
  let second = headings.assign_heading_ids("<h2>!!!</h2>")

  first |> ids |> should.equal(["heading-1"])
  second |> ids |> should.equal(["heading-1"])
}

pub fn same_input_produces_the_same_ids_test() {
  let html = "<h2>Foo</h2><h2>Foo</h2><h2>安装</h2><h2>!!!</h2><h2>😀</h2>"

  let first = headings.assign_heading_ids(html)
  let second = headings.assign_heading_ids(html)

  first |> ids |> should.equal(ids(second))
}

pub fn process_ids_only_assigns_the_same_ids_test() {
  let html = "<h1>A</h1><h2>Foo</h2><h2>Foo</h2><h2>安装</h2><h2>!!!</h2>"

  let out_html = headings.process_ids_only(html)

  let assigned = headings.assign_heading_ids(html)

  list.each(ids(assigned), fn(id) {
    out_html
    |> string.contains("id=\"" <> id <> "\"")
    |> should.equal(True)
  })
}

// RENDERED HEADINGS AND TOC CONSISTENCY --------------------------------------

pub fn rendered_heading_anchor_matches_its_id_test() {
  let #(out_html, _toc) = headings.process("<h2>Installation</h2>")

  out_html
  |> string.contains(
    "<h2 id=\"installation\"><a href=\"#installation\">Installation</a></h2>",
  )
  |> should.equal(True)
}

pub fn inline_markdown_is_stripped_before_slugging_test() {
  let #(out_html, _toc) =
    headings.process("<h2>Install <code>gleam</code></h2>")

  out_html
  |> string.contains("id=\"install-gleam\"")
  |> should.equal(True)
}

pub fn toc_includes_every_heading_level_test() {
  let html = "<h1>Doc</h1><h2>A</h2><h5>Minor</h5><h6>Minor 2</h6>"
  let #(out_html, toc) = headings.process(html)

  // Every heading level (h1–h6) is part of the ToC at its own level.
  out_html
  |> string.contains("id=\"doc\"")
  |> should.equal(True)

  out_html
  |> string.contains("id=\"minor\"")
  |> should.equal(True)

  out_html
  |> string.contains("id=\"minor-2\"")
  |> should.equal(True)

  toc_ids(toc)
  |> should.equal(["doc", "a", "minor", "minor-2"])

  // h1 is the only top-level entry; h2 nests under it, h5 under the h2, and
  // h6 under the h5.
  toc
  |> list.map(entry_level)
  |> should.equal([1])
}

pub fn toc_links_use_the_same_ids_as_rendered_headings_test() {
  let html =
    "<h2>Installation</h2><h3>Configuration</h3><h4>Advanced</h4><h2>Deployment</h2>"
  let #(out_html, toc) = headings.process(html)

  out_html
  |> string.contains("id=\"installation\"")
  |> should.equal(True)

  out_html
  |> string.contains("id=\"configuration\"")
  |> should.equal(True)

  out_html
  |> string.contains("id=\"advanced\"")
  |> should.equal(True)

  toc_ids(toc)
  |> should.equal(["installation", "configuration", "advanced", "deployment"])
}

pub fn toc_targets_resolve_to_exactly_one_rendered_heading_test() {
  let html =
    "<h2>Foo</h2><h3>Bar</h3><h2>Foo</h2><h4>Baz</h4><h1>Top</h1><h2>技术栈</h2><h2>!!!</h2>"
  let #(out_html, toc) = headings.process(html)

  list.each(toc_ids(toc), fn(id) {
    count_occurrences(out_html, "id=\"" <> id <> "\"")
    |> should.equal(1)
  })
}

pub fn toc_building_does_not_change_assigned_ids_test() {
  // Enabling/disabling the ToC must not change generated IDs: every heading
  // (h1–h6) keeps the ID assigned from the full heading list.
  let html = "<h1>Doc</h1><h2>A</h2><h3>B</h3><h4>C</h4><h5>D</h5><h6>E</h6>"
  let assigned = headings.assign_heading_ids(html)
  let #(out_html, _toc) = headings.process(html)

  list.each(ids(assigned), fn(id) {
    out_html
    |> string.contains("id=\"" <> id <> "\"")
    |> should.equal(True)
  })
}

pub fn cjk_toc_targets_use_readable_unicode_slugs_test() {
  let html = "<h2>技术栈</h2><h3>依赖项</h3>"
  let #(_out_html, toc) = headings.process(html)

  toc_ids(toc)
  |> should.equal(["技术栈", "依赖项"])
}

pub fn leading_h3_is_top_level_and_h2_sections_kept_test() {
  // A document starting with an h3 (before any h2) must not break the ToC:
  // the leading h3 has no shallower heading before it, so it becomes a
  // top-level entry, and every following h2 section is still present,
  // instead of the build stopping at the first h2.
  let html =
    "<h3>Hello, Arata</h3><h2>Why Arata</h2><h2>Why Gleam</h2><h2>Tech stack</h2>"
  let #(_out_html, toc) = headings.process(html)

  toc_ids(toc)
  |> should.equal(["hello-arata", "why-arata", "why-gleam", "tech-stack"])
}

pub fn leading_h3_is_a_top_level_entry_test() {
  // A leading h3 has no preceding h2 to nest under, so it sits at the top
  // level of the ToC, and the first h2 is also a top-level entry, not a
  // child.
  let html = "<h3>Intro</h3><h2>Body</h2><h3>Detail</h3>"
  let #(_out_html, toc) = headings.process(html)

  toc
  |> list.map(entry_level)
  |> should.equal([3, 2])

  toc
  |> list.map(fn(entry) { entry.id })
  |> should.equal(["intro", "body"])

  // "Detail" nests under its preceding h2 "Body".
  toc
  |> list.map(fn(entry) { entry.children })
  |> should.equal([
    [],
    [TocEntry(level: 3, id: "detail", title: "Detail", children: [])],
  ])
}

pub fn h3_after_h4_is_not_dropped_test() {
  // Within one h2 section, an h3 that follows an h4 (shallower than the level
  // being built) re-anchors the build instead of being dropped.
  let html = "<h2>Setup</h2><h4>Advanced</h4><h3>Default</h3><h2>Next</h2>"
  let #(_out_html, toc) = headings.process(html)

  toc_ids(toc)
  |> should.equal(["setup", "advanced", "default", "next"])
}

pub fn leading_h4_is_top_level_before_the_first_h2_test() {
  // The same re-anchoring applies when the document opens with an h4: it is
  // kept as a top-level entry and the following h2 sections still build.
  let html = "<h4>Note</h4><h2>Body</h2><h2>End</h2>"
  let #(_out_html, toc) = headings.process(html)

  toc_ids(toc)
  |> should.equal(["note", "body", "end"])
}

pub fn inverted_heading_levels_keep_document_order_test() {
  // With inverted heading levels (h4 before h3 before h2) no heading has a
  // shallower heading before it, so every heading becomes a top-level entry
  // in document order. The view derives indentation from each entry's own
  // level, so the h4 still renders deepest.
  let html = "<h4>Note</h4><h3>Body</h3><h2>End</h2>"
  let #(_out_html, toc) = headings.process(html)

  toc_ids(toc)
  |> should.equal(["note", "body", "end"])

  toc
  |> list.map(entry_level)
  |> should.equal([4, 3, 2])

  toc
  |> list.map(fn(entry) { entry.children })
  |> should.equal([[], [], []])
}

// HELPERS --------------------------------------------------------------------

/// The `id` field of every assigned heading, in document order.
fn ids(assigned: List(#(Int, String, String))) -> List(String) {
  list.map(assigned, fn(entry) {
    let #(_, id, _) = entry
    id
  })
}

/// Every ToC entry id, depth-first.
fn toc_ids(entries: List(TocEntry)) -> List(String) {
  list.flatten(
    list.map(entries, fn(entry) { [entry.id, ..toc_ids(entry.children)] }),
  )
}

/// The `level` of a top-level ToC entry.
fn entry_level(entry: TocEntry) -> Int {
  entry.level
}

/// Count non-overlapping occurrences of `needle` in `haystack`.
fn count_occurrences(haystack: String, needle: String) -> Int {
  case string.split(haystack, needle) {
    [] -> 0
    [_first, ..rest] -> list.length(rest)
  }
}
