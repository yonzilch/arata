//// Tests for the right-sidebar table of contents disclosure control and the
//// non-collapsible table of contents used by the floating overlay.

import data/post.{type TocEntry, TocEntry}
import gleam/option
import gleam/string
import gleeunit
import gleeunit/should
import lustre/element

import view/toc

pub fn main() -> Nil {
  gleeunit.main()
}

type Msg {
  ToggleToc
}

pub fn expanded_toc_renders_downward_disclosure_test() {
  let rendered =
    toc.view(sample_entries(), option.None, True, ToggleToc, no_op_select)
    |> element.to_string

  rendered
  |> string.contains("▼")
  |> should.equal(True)

  rendered
  |> string.contains("▶")
  |> should.equal(False)
}

pub fn collapsed_toc_renders_right_disclosure_test() {
  let rendered =
    toc.view(sample_entries(), option.None, False, ToggleToc, no_op_select)
    |> element.to_string

  rendered
  |> string.contains("▶")
  |> should.equal(True)

  rendered
  |> string.contains("▼")
  |> should.equal(False)
}

pub fn expanded_toc_exposes_expanded_aria_state_test() {
  let rendered =
    toc.view(sample_entries(), option.None, True, ToggleToc, no_op_select)
    |> element.to_string

  rendered
  |> string.contains("aria-expanded=\"true\"")
  |> should.equal(True)

  rendered
  |> string.contains("aria-controls=\"sidebar-table-of-contents\"")
  |> should.equal(True)
}

pub fn collapsed_toc_exposes_collapsed_aria_state_test() {
  let rendered =
    toc.view(sample_entries(), option.None, False, ToggleToc, no_op_select)
    |> element.to_string

  rendered
  |> string.contains("aria-expanded=\"false\"")
  |> should.equal(True)

  rendered
  |> string.contains("aria-controls=\"sidebar-table-of-contents\"")
  |> should.equal(True)
}

pub fn disclosure_indicator_is_hidden_from_accessibility_tree_test() {
  let expanded =
    toc.view(sample_entries(), option.None, True, ToggleToc, no_op_select)
    |> element.to_string

  let collapsed =
    toc.view(sample_entries(), option.None, False, ToggleToc, no_op_select)
    |> element.to_string

  expanded
  |> string.contains("aria-hidden=\"true\"")
  |> should.equal(True)

  collapsed
  |> string.contains("aria-hidden=\"true\"")
  |> should.equal(True)
}

pub fn expanded_toc_keeps_entries_container_visible_test() {
  let rendered =
    toc.view(sample_entries(), option.None, True, ToggleToc, no_op_select)
    |> element.to_string

  rendered
  |> string.contains("id=\"sidebar-table-of-contents\"")
  |> should.equal(True)

  rendered
  |> string.contains("class=\"toc-list\"")
  |> should.equal(True)

  rendered
  |> string.contains(" hidden")
  |> should.equal(False)
}

pub fn collapsed_toc_hides_entries_container_test() {
  let rendered =
    toc.view(sample_entries(), option.None, False, ToggleToc, no_op_select)
    |> element.to_string

  rendered
  |> string.contains("id=\"sidebar-table-of-contents\"")
  |> should.equal(True)

  rendered
  |> string.contains("class=\"toc-list\"")
  |> should.equal(True)

  rendered
  |> string.contains(" hidden")
  |> should.equal(True)
}

pub fn toc_control_uses_native_button_semantics_test() {
  let rendered =
    toc.view(sample_entries(), option.None, True, ToggleToc, no_op_select)
    |> element.to_string

  rendered
  |> string.contains("<button")
  |> should.equal(True)

  rendered
  |> string.contains("type=\"button\"")
  |> should.equal(True)

  rendered
  |> string.contains("class=\"heading toc-toggle\"")
  |> should.equal(True)

  rendered
  |> string.contains("Table of Contents")
  |> should.equal(True)

  rendered
  |> string.contains("role=\"button\"")
  |> should.equal(False)
}

pub fn empty_toc_renders_nothing_test() {
  let rendered =
    toc.view([], option.None, True, ToggleToc, no_op_select)
    |> element.to_string

  rendered
  |> should.equal("")
}

pub fn empty_static_toc_renders_nothing_test() {
  let rendered =
    toc.view_static([], option.None, no_op_select)
    |> element.to_string

  rendered
  |> should.equal("")
}

pub fn static_toc_does_not_render_disclosure_control_test() {
  let rendered =
    toc.view_static(sample_entries(), option.None, no_op_select)
    |> element.to_string

  rendered
  |> string.contains("Table of Contents")
  |> should.equal(True)

  rendered
  |> string.contains("class=\"toc-list\"")
  |> should.equal(True)

  rendered
  |> string.contains("toc-toggle")
  |> should.equal(False)

  rendered
  |> string.contains("aria-expanded")
  |> should.equal(False)

  rendered
  |> string.contains("aria-controls")
  |> should.equal(False)

  rendered
  |> string.contains("▶")
  |> should.equal(False)

  rendered
  |> string.contains("▼")
  |> should.equal(False)
}

pub fn toc_renders_all_heading_links_test() {
  let rendered =
    toc.view(sample_entries(), option.None, True, ToggleToc, no_op_select)
    |> element.to_string

  rendered
  |> string.contains("href=\"#installation\"")
  |> should.equal(True)

  rendered
  |> string.contains("href=\"#configuration\"")
  |> should.equal(True)

  rendered
  |> string.contains("href=\"#advanced-options\"")
  |> should.equal(True)

  rendered
  |> string.contains("href=\"#deployment\"")
  |> should.equal(True)
}

pub fn entries_are_rendered_flat_with_level_based_depth_classes_test() {
  let rendered =
    toc.view(sample_entries(), option.None, True, ToggleToc, no_op_select)
    |> element.to_string

  // The tree is flattened into document order; each entry's indentation
  // class derives from its own heading level (min level here is h2).
  rendered
  |> string.contains("class=\"toc-depth-1 \"")
  |> should.equal(True)

  rendered
  |> string.contains("class=\"toc-depth-2 \"")
  |> should.equal(True)

  rendered
  |> string.contains("class=\"toc-depth-3 \"")
  |> should.equal(True)

  // No nested `<ul>` is produced anymore.
  rendered
  |> string.contains("<ul>")
  |> should.equal(False)
}

pub fn depth_classes_are_relative_to_the_documents_minimum_level_test() {
  let entries = [
    TocEntry(level: 1, id: "doc", title: "Doc", children: []),
    TocEntry(level: 2, id: "section", title: "Section", children: []),
    TocEntry(level: 6, id: "deep", title: "Deep", children: []),
  ]

  let rendered =
    toc.view(entries, option.None, True, ToggleToc, no_op_select)
    |> element.to_string

  rendered
  |> string.contains("class=\"toc-depth-1 \"")
  |> should.equal(True)

  rendered
  |> string.contains("class=\"toc-depth-2 \"")
  |> should.equal(True)

  rendered
  |> string.contains("class=\"toc-depth-6 \"")
  |> should.equal(True)
}

pub fn active_top_level_heading_highlights_itself_test() {
  let rendered =
    toc.view(
      sample_entries(),
      option.Some("installation"),
      True,
      ToggleToc,
      no_op_select,
    )
    |> element.to_string

  // The active h2 is a top-level entry with no ancestor, so it highlights
  // itself with both `.selected` and `.parent`.
  rendered
  |> string.contains("class=\"toc-depth-1 parent selected \"")
  |> should.equal(True)
}

pub fn active_h3_highlights_itself_and_its_parent_h2_test() {
  let rendered =
    toc.view(
      sample_entries(),
      option.Some("configuration"),
      True,
      ToggleToc,
      no_op_select,
    )
    |> element.to_string

  // The active h3 highlights itself (`.selected`) and its ancestor — the h2
  // "installation" — is marked as `.parent`.
  rendered
  |> string.contains("class=\"toc-depth-2 selected \"")
  |> should.equal(True)

  rendered
  |> string.contains("class=\"toc-depth-1 parent \"")
  |> should.equal(True)
}

pub fn active_h4_highlights_itself_plus_all_ancestors_test() {
  let rendered =
    toc.view(
      sample_entries(),
      option.Some("advanced-options"),
      True,
      ToggleToc,
      no_op_select,
    )
    |> element.to_string

  // The active h4 highlights itself (`.selected`) and every ancestor on the
  // path up: the h3 "configuration" and the top-level h2 "installation"
  // both receive `.parent`.
  rendered
  |> string.contains("class=\"toc-depth-3 selected \"")
  |> should.equal(True)

  rendered
  |> string.contains("class=\"toc-depth-2 parent \"")
  |> should.equal(True)

  rendered
  |> string.contains("class=\"toc-depth-1 parent \"")
  |> should.equal(True)

  // The h3 itself is not `.selected` (only the active h4 is).
  rendered
  |> string.contains("class=\"toc-depth-2 selected \"")
  |> should.equal(False)
}

pub fn leading_deep_heading_without_ancestor_highlights_itself_test() {
  // hello-arata shape: the first heading is an h3 with no preceding h2, so
  // upward selection finds nothing and the h3 highlights itself.
  let entries = [
    TocEntry(level: 3, id: "hello-arata", title: "Hello, Arata", children: []),
    TocEntry(level: 2, id: "why-arata", title: "Why Arata", children: []),
  ]

  let rendered =
    toc.view(entries, option.Some("hello-arata"), True, ToggleToc, no_op_select)
    |> element.to_string

  rendered
  |> string.contains("class=\"toc-depth-2 parent selected \"")
  |> should.equal(True)

  rendered
  |> string.contains("class=\"toc-depth-1 parent selected \"")
  |> should.equal(False)
}

pub fn unknown_active_heading_selects_no_entry_test() {
  let rendered =
    toc.view(
      sample_entries(),
      option.Some("missing-heading"),
      True,
      ToggleToc,
      no_op_select,
    )
    |> element.to_string

  rendered
  |> string.contains("class=\"selected \"")
  |> should.equal(False)

  rendered
  |> string.contains("class=\"parent \"")
  |> should.equal(False)
}

fn no_op_select(_id: String) -> Msg {
  ToggleToc
}

fn sample_entries() -> List(TocEntry) {
  [
    TocEntry(level: 2, id: "installation", title: "Installation", children: [
      TocEntry(level: 3, id: "configuration", title: "Configuration", children: [
        TocEntry(
          level: 4,
          id: "advanced-options",
          title: "Advanced options",
          children: [],
        ),
      ]),
    ]),
    TocEntry(level: 2, id: "deployment", title: "Deployment", children: []),
  ]
}
