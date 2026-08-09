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
    toc.view(sample_entries(), option.None, True, ToggleToc)
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
    toc.view(sample_entries(), option.None, False, ToggleToc)
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
    toc.view(sample_entries(), option.None, True, ToggleToc)
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
    toc.view(sample_entries(), option.None, False, ToggleToc)
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
    toc.view(sample_entries(), option.None, True, ToggleToc)
    |> element.to_string

  let collapsed =
    toc.view(sample_entries(), option.None, False, ToggleToc)
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
    toc.view(sample_entries(), option.None, True, ToggleToc)
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
    toc.view(sample_entries(), option.None, False, ToggleToc)
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
    toc.view(sample_entries(), option.None, True, ToggleToc)
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
    toc.view([], option.None, True, ToggleToc)
    |> element.to_string

  rendered
  |> should.equal("")
}

pub fn empty_static_toc_renders_nothing_test() {
  let rendered =
    toc.view_static([], option.None)
    |> element.to_string

  rendered
  |> should.equal("")
}

pub fn static_toc_does_not_render_disclosure_control_test() {
  let rendered =
    toc.view_static(sample_entries(), option.None)
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

pub fn toc_renders_nested_heading_links_test() {
  let rendered =
    toc.view(sample_entries(), option.None, True, ToggleToc)
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

pub fn active_top_level_heading_is_selected_and_parent_test() {
  let rendered =
    toc.view(
      sample_entries(),
      option.Some("installation"),
      True,
      ToggleToc,
    )
    |> element.to_string

  rendered
  |> string.contains("class=\"parent selected \"")
  |> should.equal(True)
}

pub fn active_nested_heading_marks_top_level_parent_test() {
  let rendered =
    toc.view(
      sample_entries(),
      option.Some("configuration"),
      True,
      ToggleToc,
    )
    |> element.to_string

  rendered
  |> string.contains("class=\"parent \"")
  |> should.equal(True)

  rendered
  |> string.contains("class=\"selected \"")
  |> should.equal(True)
}

pub fn active_deeply_nested_heading_marks_top_level_parent_test() {
  let rendered =
    toc.view(
      sample_entries(),
      option.Some("advanced-options"),
      True,
      ToggleToc,
    )
    |> element.to_string

  rendered
  |> string.contains("class=\"parent \"")
  |> should.equal(True)

  rendered
  |> string.contains("class=\"selected \"")
  |> should.equal(True)
}

pub fn unknown_active_heading_selects_no_entry_test() {
  let rendered =
    toc.view(
      sample_entries(),
      option.Some("missing-heading"),
      True,
      ToggleToc,
    )
    |> element.to_string

  rendered
  |> string.contains("class=\"selected \"")
  |> should.equal(False)

  rendered
  |> string.contains("class=\"parent \"")
  |> should.equal(False)
}

fn sample_entries() -> List(TocEntry) {
  [
    TocEntry(
      id: "installation",
      title: "Installation",
      children: [
        TocEntry(
          id: "configuration",
          title: "Configuration",
          children: [
            TocEntry(
              id: "advanced-options",
              title: "Advanced options",
              children: [],
            ),
          ],
        ),
      ],
    ),
    TocEntry(
      id: "deployment",
      title: "Deployment",
      children: [],
    ),
  ]
}
