//// Table of contents view: renders a 3-level nested `<ul>` of heading links
//// in the `.right-content` sidebar, mirroring apollo's
//// `templates/partials/toc.html`.
////
//// Active highlighting is driven declaratively from the model: the
//// IntersectionObserver effect (see `effect/toc.gleam`) dispatches
//// `TocActiveHeadingChanged(id)` messages, the model stores the active
//// heading id, and this view applies the `.selected` / `.parent` classes by
//// comparing each entry's id to the active one. This is the idiomatic
//// Lustre/Elm-architecture approach with no direct DOM class manipulation.
////
//// The TOC is hidden below 1365px viewport via the `.toc` CSS rule ported
//// from apollo.
////
//// The right-side TOC can be expanded or collapsed through its heading
//// button. The expanded state is owned by the parent Lustre model and passed
//// into this view together with the message dispatched by the toggle button.
//// The entries container remains mounted and uses the native `hidden`
//// attribute while collapsed so `aria-controls` always references an
//// existing element and hidden links are removed from keyboard navigation
//// and the accessibility tree.

import data/post.{type TocEntry}
import gleam/list
import gleam/option.{type Option}
import gleam/string
import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html
import lustre/event

const toc_entries_id = "sidebar-table-of-contents"

/// Render the TOC for a post.
///
/// `entries` is the post's `toc` list containing top-level h2 headings and
/// their nested h3 and h4 children.
///
/// `active_heading` is the id of the heading currently in view, or `None` if
/// none has been scrolled to yet.
///
/// `expanded` controls whether the TOC entries are visible. `on_toggle` is
/// dispatched when the user activates the Table of Contents heading.
///
/// When `entries` is empty, this function returns `element.none()` so the
/// sidebar does not render an empty interactive control.
pub fn view(
  entries: List(TocEntry),
  active_heading: Option(String),
  expanded: Bool,
  on_toggle: msg,
) -> Element(msg) {
  case entries {
    [] -> none()

    _ -> {
      let entries_attributes = case expanded {
        True -> [
          attribute.id(toc_entries_id),
          attribute.class("toc-list"),
        ]

        False -> [
          attribute.id(toc_entries_id),
          attribute.class("toc-list"),
          attribute.attribute("hidden", ""),
        ]
      }

      html.div([attribute.class("toc")], [
        html.button(
          [
            attribute.attribute("type", "button"),
            attribute.class("heading toc-toggle"),
            attribute.attribute(
              "aria-expanded",
              string.lowercase(string.inspect(expanded)),
            ),
            attribute.attribute("aria-controls", toc_entries_id),
            event.on_click(on_toggle),
          ],
          [
            html.span(
              [
                attribute.class("toc-disclosure"),
                attribute.attribute("aria-hidden", "true"),
              ],
              [
                html.text(case expanded {
                  True -> "▼"
                  False -> "▶"
                }),
              ],
            ),
            html.span([], [html.text("Table of Contents")]),
          ],
        ),
        html.ul(
          entries_attributes,
          list.map(entries, fn(entry) {
            view_entry(entry, active_heading)
          }),
        ),
      ])
    }
  }
}

/// Render one top-level TOC entry and its nested children.
///
/// A top-level entry is a `.parent` candidate. It receives the `.parent` class
/// when the active heading is this entry or any of its descendants.
fn view_entry(entry: TocEntry, active_heading: Option(String)) -> Element(msg) {
  let is_selected = is_active(entry.id, active_heading)
  let is_parent =
    is_selected || any_child_active(entry.children, active_heading)

  let link =
    html.a(
      [attribute.href("#" <> entry.id)],
      [html.text(entry.title)],
    )

  let children = case entry.children {
    [] -> []

    _ -> [
      html.ul(
        [],
        list.map(entry.children, fn(child) {
          view_child(child, active_heading)
        }),
      ),
    ]
  }

  html.li(
    [
      attribute.classes([
        #("parent", is_parent),
        #("selected", is_selected),
      ]),
    ],
    [link, ..children],
  )
}

/// Render a second-level entry and its nested third-level entries.
///
/// Second-level entries only receive `.selected`, never `.parent`, because
/// apollo's CSS targets `.toc .parent > a` for the top-level highlight. The
/// recursion allows h4 headings to render as children of their preceding h3.
fn view_child(entry: TocEntry, active_heading: Option(String)) -> Element(msg) {
  let is_selected = is_active(entry.id, active_heading)

  let link =
    html.a(
      [attribute.href("#" <> entry.id)],
      [html.text(entry.title)],
    )

  let children = case entry.children {
    [] -> []

    _ -> [
      html.ul(
        [],
        list.map(entry.children, fn(child) {
          view_child(child, active_heading)
        }),
      ),
    ]
  }

  html.li(
    [attribute.classes([#("selected", is_selected)])],
    [link, ..children],
  )
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
  list.any(children, fn(child) {
    is_active(child.id, active_heading)
    || any_child_active(child.children, active_heading)
  })
}

/// Render a non-collapsible TOC.
///
/// This variant is used by the floating TOC overlay and remains independent
/// from the right sidebar's expanded state.
pub fn view_static(
  entries: List(TocEntry),
  active_heading: Option(String),
) -> Element(msg) {
  case entries {
    [] -> none()

    _ ->
      html.div([attribute.class("toc")], [
        html.div(
          [attribute.class("heading")],
          [html.text("Table of Contents")],
        ),
        html.ul(
          [attribute.class("toc-list")],
          list.map(entries, fn(entry) {
            view_entry(entry, active_heading)
          }),
        ),
      ])
  }
}
