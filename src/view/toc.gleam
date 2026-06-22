//// Table of contents view: renders a 3-level nested `<ul>` of heading links
//// in the `.right-content` sidebar, mirroring apollo's
//// `templates/partials/toc.html`.
////
//// Active highlighting is driven declaratively from the model: the
//// IntersectionObserver effect (see `effect/toc.gleam`) dispatches
//// `TocActiveHeadingChanged(id)` messages, the model stores the active
//// heading id, and this view applies the `.selected` / `.parent` classes by
//// comparing each entry's id to the active one. This is the idiomatic
//// Lustre/Elm-architecture approach — no direct DOM class manipulation.
////
//// The TOC is hidden below 1365px viewport (via the `.toc` CSS rule ported
//// from apollo).

import data/post.{type TocEntry}
import gleam/list
import gleam/option.{type Option}
import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html

/// Render the TOC for a post.
///
/// `entries` is the post's `toc` list (top-level h2 headings, each with
/// optional nested h3 `children`). `active_heading` is the id of the heading
/// currently in view (or `None` if none has been scrolled to yet). When
/// `entries` is empty, returns `element.none()` so the sidebar stays empty.
pub fn view(
  entries: List(TocEntry),
  active_heading: Option(String),
) -> Element(msg) {
  case entries {
    [] -> none()
    _ ->
      html.div([attribute.class("toc")], [
        html.div([attribute.class("heading")], [html.text("Table of Contents")]),
        html.ul(
          [attribute.class("toc-list")],
          list.map(entries, fn(entry) { view_entry(entry, active_heading) }),
        ),
      ])
  }
}

/// Render one top-level TOC entry and its nested children. A top-level entry
/// is a `.parent` candidate: it gets the `.parent` class when the active
/// heading is this entry or any of its descendants.
fn view_entry(entry: TocEntry, active_heading: Option(String)) -> Element(msg) {
  let is_selected = is_active(entry.id, active_heading)
  let is_parent =
    is_selected || any_child_active(entry.children, active_heading)
  let link = html.a([attribute.href("#" <> entry.id)], [html.text(entry.title)])
  let children = case entry.children {
    [] -> []
    _ -> [
      html.ul(
        [],
        list.map(entry.children, fn(child) { view_child(child, active_heading) }),
      ),
    ]
  }
  html.li(
    [attribute.classes([#("parent", is_parent), #("selected", is_selected)])],
    [link, ..children],
  )
}

/// Render a second-level entry (an h3 inside an h2). Second-level entries only
/// get `.selected`, never `.parent` (apollo's CSS targets `.toc .parent > a`
/// for the top-level highlight).
fn view_child(entry: TocEntry, active_heading: Option(String)) -> Element(msg) {
  let is_selected = is_active(entry.id, active_heading)
  html.li([attribute.classes([#("selected", is_selected)])], [
    html.a([attribute.href("#" <> entry.id)], [html.text(entry.title)]),
  ])
}

fn is_active(id: String, active_heading: Option(String)) -> Bool {
  case active_heading {
    option.Some(active) -> id == active
    option.None -> False
  }
}

fn any_child_active(
  children: List(TocEntry),
  active_heading: Option(String),
) -> Bool {
  list.any(children, fn(child) { is_active(child.id, active_heading) })
}
