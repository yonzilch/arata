//// Search modal view: renders the Cmd/Ctrl+K search overlay with an input,
//// results list, and keyboard navigation, mirroring apollo's
//// `partials/nav.html` search modal markup and `searchElasticlunr.js` modal
//// controller.
////
//// The modal is conditionally rendered (only when `open` is True). The caller
//// provides message constructors for input changes, clearing, result
//// selection, and keydown events so the view stays polymorphic over `msg`.
////
//// apollo's modal uses `#searchModal`, `#modal-content`, `#searchBar`,
//// `#searchInput`, `.clear-button`, `#results-container`, `#results`, and
//// `aria-selected` for the selected result. arata reproduces the same IDs and
//// classes so the ported `.search-modal` CSS applies.

import data/search.{type SearchResult}
import gleam/int
import gleam/list
import lustre/attribute
import lustre/element.{type Element, none, unsafe_raw_html}
import lustre/element/html
import lustre/event

/// Render the search modal. Returns `element.none()` when `open` is `False`.
///
/// `on_close` is dispatched when the user clicks the backdrop overlay (the area
/// outside `#modal-content`). The backdrop is a separate sibling element behind
/// `#modal-content`, so clicks on the dialog body don't bubble up to the
/// backdrop's onclick handler — only clicks on the dimmed area close the modal.
pub fn view(
  open: Bool,
  query: String,
  results: List(SearchResult),
  selected_index: Int,
  on_input_change: fn(String) -> msg,
  on_clear: msg,
  on_close: msg,
  on_result_click: fn(String) -> msg,
  on_keydown: fn(String) -> msg,
) -> Element(msg) {
  case open {
    False -> none()
    True ->
      html.div(
        [
          attribute.id("searchModal"),
          attribute.class("search-modal js"),
          attribute.attribute("role", "dialog"),
          attribute.attribute("aria-labelledby", "modalTitle"),
        ],
        [
          // The clickable backdrop: covers the full viewport, sits behind the
          // dialog. Only clicks landing here (i.e. outside `#modal-content`)
          // fire `on_close` — `#modal-content` is a sibling, not a child, so
          // its clicks don't bubble to this handler.
          html.div(
            [attribute.class("search-backdrop"), event.on_click(on_close)],
            [],
          ),
          html.div([attribute.id("modal-content")], [
            html.h1(
              [attribute.id("modalTitle"), attribute.class("page-header")],
              [
                html.text("Search"),
              ],
            ),
            html.div([attribute.id("searchBar")], [
              html.input([
                attribute.id("searchInput"),
                attribute.type_("text"),
                attribute.placeholder("Search..."),
                attribute.value(query),
                // Fix 4 — auto-focus the search input when the modal opens.
                // Because the modal goes from `none()` to a real element on
                // open, the browser sees a freshly-inserted `#searchInput`
                // with `autofocus` and focuses it as part of the DOM insertion.
                // This avoids the need for a Lustre effect / FFI focus call.
                attribute.attribute("autofocus", ""),
                attribute.attribute("role", "combobox"),
                attribute.attribute("autocomplete", "off"),
                attribute.attribute("spellcheck", "false"),
                attribute.attribute("aria-expanded", "true"),
                attribute.attribute("aria-controls", "results-container"),
                event.on_input(on_input_change),
                event.on_keydown(on_keydown),
              ]),
              html.button(
                [
                  attribute.id("clear-search"),
                  attribute.class("clear-button"),
                  attribute.attribute("title", "Clear search"),
                  event.on_click(on_clear),
                ],
                [clear_icon()],
              ),
            ]),
            html.div([attribute.id("results-container")], [
              view_results_info(results),
              html.div(
                [
                  attribute.id("results"),
                  attribute.attribute("role", "listbox"),
                ],
                list.index_map(results, fn(result, index) {
                  view_result(result, index == selected_index, on_result_click)
                }),
              ),
            ]),
          ]),
        ],
      )
  }
}

/// The results count line: "No results", "1 result", or "N results".
fn view_results_info(results: List(SearchResult)) -> Element(msg) {
  let count = list.length(results)
  let text = case count {
    0 -> "No results"
    1 -> "1 result"
    _ -> int.to_string(count) <> " results"
  }
  html.div([attribute.id("results-info")], [html.text(text)])
}

/// One search result row. `is_selected` adds `aria-selected="true"` so the
/// ported CSS highlights it. Clicking navigates to the post.
fn view_result(
  result: SearchResult,
  is_selected: Bool,
  on_result_click: fn(String) -> msg,
) -> Element(msg) {
  let post = result.post
  let selected_attr = case is_selected {
    True -> attribute.attribute("aria-selected", "true")
    False -> attribute.none()
  }
  html.div(
    [
      attribute.attribute("role", "option"),
      selected_attr,
      event.on_click(on_result_click(post.slug)),
    ],
    [
      html.span([], [html.text(post.title)]),
      html.span([], [html.text(post.description)]),
    ],
  )
}

/// The clear (×) SVG icon, inlined from apollo's `nav.html`.
fn clear_icon() -> Element(msg) {
  unsafe_raw_html(
    "",
    "svg",
    [
      attribute.attribute("xmlns", "http://www.w3.org/2000/svg"),
      attribute.attribute("viewBox", "0 -960 960 960"),
    ],
    "<path d=\"m256-200-56-56 224-224-224-224 56-56 224 224 224-224 56 56-224 224 224 224-56 56-224-224-224 224Z\" />",
  )
}
