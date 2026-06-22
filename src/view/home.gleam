//// Homepage view: renders the custom landing page, mirroring apollo's
//// `templates/homepage.html`.
////
//// apollo's homepage template renders `<main><article><section class="body">`
//// containing the `page_header` (the site title) followed by the homepage
//// markdown body. arata does the same: a `.page-header` with the title (and
//// optional subtitle), then the pre-rendered HTML body via
//// `unsafe_raw_html`.

import data/markdown
import data/page.{type Page}
import gleam/option
import lustre/attribute
import lustre/element.{type Element, unsafe_raw_html}
import lustre/element/html
import view/wavy_boundary

/// Render the homepage. The wavy boundary is inserted between the hero
/// section (the page-header + subtitle) and the body content, creating a soft
/// visual transition. The wave uses `var(--bg-0)` above and `var(--bg-1)`
/// below so it blends into the body section.
pub fn view(home: Page) -> Element(msg) {
  html.main([], [
    html.article([], [
      html.section([attribute.class("body")], [
        html.div([attribute.class("page-header")], [
          html.text(home.title),
          ..view_subtitle(home.subtitle)
        ]),
        wavy_boundary.view("var(--bg-0)", "var(--bg-1)"),
        unsafe_raw_html("", "div", [], markdown.to_html(home.body)),
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
