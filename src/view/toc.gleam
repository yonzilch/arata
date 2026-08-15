//// Table of contents view: renders the heading links in the `.right-content`
//// sidebar, mirroring apollo's `templates/partials/toc.html`.
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
////
//// ## Rendering
////
//// Every heading level (h1–h6) appears in the ToC. The nested `TocEntry`
//// tree from the build step is flattened back into document order (a
//// preorder traversal) and rendered as a flat list: each entry's indentation
//// comes from its own heading level, not from its tree depth, via a
//// `toc-depth-N` class (`N = level − min_level + 1`). This keeps malformed
//// documents (inverted heading levels, leading deep headings) readable — a
//// heading is always shown at the depth its level implies, regardless of
//// where it sits in the tree.
////
//// ## Highlighting
////
//// The current heading is always highlighted (`selected`), and the
//// upward-selection rule additionally highlights every ancestor on the path
//// from the current heading to the top of its section (`parent`). So an
//// active h4 highlights itself plus its h3 and the top-level h2, an active
//// h3 highlights itself plus its h2, and a heading with no shallower heading
//// before it (e.g. a leading h3 before any h2) highlights only itself.

import data/post.{type TocEntry}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/string
import lustre/attribute.{type Attribute}
import lustre/element.{type Element, none}
import lustre/element/html
import lustre/event

const toc_entries_id = "sidebar-table-of-contents"

/// Render the TOC for a post.
///
/// `entries` is the post's `toc` list containing every heading (h1–h6) with
/// its nested children.
///
/// `active_heading` is the id of the heading currently in view, or `None` if
/// none has been scrolled to yet.
///
/// `expanded` controls whether the TOC entries are visible. `on_toggle` is
/// dispatched when the user activates the Table of Contents heading, and
/// `on_select` when the user activates a heading link.
///
/// When `entries` is empty, this function returns `element.none()` so the
/// sidebar does not render an empty interactive control.
pub fn view(
  entries: List(TocEntry),
  active_heading: Option(String),
  expanded: Bool,
  on_toggle: msg,
  on_select: fn(String) -> msg,
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
          flat_entries(entries, active_heading, on_select),
        ),
      ])
    }
  }
}

/// Render a non-collapsible TOC.
///
/// This variant is used by the floating TOC overlay and remains independent
/// from the right sidebar's expanded state.
pub fn view_static(
  entries: List(TocEntry),
  active_heading: Option(String),
  on_select: fn(String) -> msg,
) -> Element(msg) {
  case entries {
    [] -> none()

    _ ->
      html.div([attribute.class("toc")], [
        html.div([attribute.class("heading")], [html.text("Table of Contents")]),
        html.ul(
          [attribute.class("toc-list")],
          flat_entries(entries, active_heading, on_select),
        ),
      ])
  }
}

/// Render the whole ToC as one flat list: the nested tree is traversed in
/// document order (preorder) so every heading appears exactly once, and each
/// entry's indentation is derived from its own heading level.
fn flat_entries(
  entries: List(TocEntry),
  active_heading: Option(String),
  on_select: fn(String) -> msg,
) -> List(Element(msg)) {
  let min = min_level(entries)
  let flat = flatten(entries)

  let #(selected_id, parent_ids) = case active_heading {
    option.Some(active) -> highlight_targets(entries, active)
    option.None -> #(option.None, [])
  }

  list.map(flat, fn(entry) {
    let depth = int.max(1, entry.level - min + 1)
    let is_selected = case selected_id {
      option.Some(id) -> id == entry.id
      option.None -> False
    }
    let is_parent = list.contains(parent_ids, entry.id)

    html.li(
      [
        attribute.classes([
          #("toc-depth-" <> int.to_string(depth), True),
          #("parent", is_parent),
          #("selected", is_selected),
        ]),
      ],
      [
        html.a(
          [
            attribute.href("#" <> entry.id),
            select_link_click(on_select(entry.id)),
          ],
          [html.text(entry.title)],
        ),
      ],
    )
  })
}

/// Flatten the nested `TocEntry` tree into document order. Because the build
/// step nests each heading under the nearest preceding shallower heading, a
/// preorder traversal visits entries in the same order as the document.
fn flatten(entries: List(TocEntry)) -> List(TocEntry) {
  list.flatten(
    list.map(entries, fn(entry) { [entry, ..flatten(entry.children)] }),
  )
}

/// The smallest heading level present anywhere in the ToC. Indentation is
/// measured relative to this level, so a document whose shallowest heading is
/// an h1 indents h2 one step, h3 two steps, and so on.
fn min_level(entries: List(TocEntry)) -> Int {
  list.fold(list.flat_map(entries, collect_levels), 6, int.min)
}

fn collect_levels(entry: TocEntry) -> List(Int) {
  [entry.level, ..list.flat_map(entry.children, collect_levels)]
}

/// Compute the ids that carry the highlight for the active heading. The
/// active heading itself always receives `.selected`, and every ancestor on
/// the path from it to the top of its section receives `.parent`:
///
///   - `selected_id` is the active heading's id;
///   - `parent_ids` are the ids of all its ancestors, nearest first, or the
///     active id itself when it has no ancestor (a top-level entry);
///   - both are empty when the active id is not present in the tree (a stale
///     or missing fragment target).
fn highlight_targets(
  entries: List(TocEntry),
  active_id: String,
) -> #(Option(String), List(String)) {
  case find_ancestors(entries, [], active_id) {
    option.None -> #(option.None, [])
    // No ancestors: the active heading is top-level, so it is both the
    // selected entry and its own top-level ancestor.
    option.Some([]) -> #(option.Some(active_id), [active_id])
    // `ancestors` runs nearest-first: [parent, grandparent, ..., root].
    option.Some(path) -> #(
      option.Some(active_id),
      list.map(path, fn(ancestor) { ancestor.id }),
    )
  }
}

/// Locate the entry whose id equals `active_id` and return its ancestor
/// chain, nearest first (`[parent, grandparent, ..., root]`). `None` when the
/// id does not exist in the tree.
fn find_ancestors(
  entries: List(TocEntry),
  ancestors: List(TocEntry),
  active_id: String,
) -> Option(List(TocEntry)) {
  case entries {
    [] -> option.None

    [entry, ..rest] ->
      case entry.id == active_id {
        True -> option.Some(ancestors)

        False ->
          case find_ancestors(entry.children, [entry, ..ancestors], active_id) {
            option.Some(path) -> option.Some(path)
            option.None -> find_ancestors(rest, ancestors, active_id)
          }
      }
  }
}

/// Build the click handler for a heading link: prevent the browser's default
/// fragment jump and stop propagation so `modem` does not intercept the click
/// and re-dispatch the current route. The app runs the fragment-navigation
/// effects (URL update + centered scroll) instead.
fn select_link_click(message: msg) -> Attribute(msg) {
  event.advanced("click", decode.success(event.handler(message, True, True)))
}
