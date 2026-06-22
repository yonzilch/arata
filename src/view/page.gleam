//// Standalone page view: renders a page's title and body, mirroring apollo's
//// `templates/page.html` (without the post-specific meta row, TOC, or tags).
////
//// apollo renders standalone pages (like `/about`) with the same `page.html`
//// template as posts, but without the date/word-count meta, TOC, or tags.
//// arata renders a simpler `<main><article>` with just a `.page-header` title
//// and the body via `unsafe_raw_html`.

import data/page.{type Page}
import lustre/attribute
import lustre/element.{type Element, unsafe_raw_html}
import lustre/element/html

/// Render a standalone page.
pub fn view(page: Page) -> Element(msg) {
  html.main([], [
    html.article([], [
      html.div([attribute.class("page-header")], [html.text(page.title)]),
      unsafe_raw_html("", "section", [attribute.class("body")], page.body),
    ]),
  ])
}
