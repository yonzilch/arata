//// Page layout shell: the apollo 3-column flex layout that wraps every page.
////
//// Mirrors apollo's `templates/base.html` `<body>` structure: an empty
//// `.left-content` spacer, a `.content` column containing the page children
//// (header, main, footer), and a `.right-content` sidebar. The sidebar hosts
//// the table of contents on single-post pages (populated from Phase 6 on);
//// on other pages it is empty and collapses (it is hidden below 1365px and
//// is a flex spacer above).
////
//// Apollo makes `<body>` the flex container. arata is mounted by Lustre inside
//// `<div id="app">`, so the single root element returned here carries the
//// `arata-shell` class for the Phase 1 CSS to target as the flex container.

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

/// Render the application shell around page content.
///
/// `children` is the list of top-level elements inside `.content` — typically
/// the header (`<nav>`), a `<main>`, and the `<footer>`. `right_content` is
/// the optional sidebar element (e.g. the TOC); pass `element.none()` when the
/// page has no sidebar.
pub fn view(
  children: List(Element(msg)),
  right_content: Element(msg),
) -> Element(msg) {
  html.div([attribute.class("arata-shell")], [
    html.div([attribute.class("left-content")], []),
    html.div([attribute.class("content")], children),
    html.div([attribute.class("right-content")], [right_content]),
  ])
}
