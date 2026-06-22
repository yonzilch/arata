//// Homepage view: renders the custom landing page, mirroring apollo's
//// `templates/homepage.html`.
////
//// apollo's homepage template renders `<main><article><section class="body">`
//// containing the `page_header` (the site title) followed by the homepage
//// markdown body. arata does the same: a `.page-header` with the title (and
//// optional subtitle), then the pre-rendered HTML body via
//// `unsafe_raw_html`.

import data/page.{type Page}
import gleam/option
import lustre/attribute
import lustre/element.{type Element, unsafe_raw_html}
import lustre/element/html

/// Render the homepage.
pub fn view(home: Page) -> Element(msg) {
  html.main([], [
    html.article([], [
      html.section([attribute.class("body")], [
        html.div([attribute.class("page-header")], [
          html.text(home.title),
          ..view_subtitle(home.subtitle)
        ]),
        unsafe_raw_html("", "div", [], home.body),
      ]),
    ]),
  ])
}

fn view_subtitle(subtitle: option.Option(String)) -> List(Element(msg)) {
  case subtitle {
    option.Some(text) -> [
      html.br([]),
      html.small([], [html.text(text)]),
    ]
    option.None -> []
  }
}
