//// Links page view: renders friend links as a simple list.

import data/link.{type Link}
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

/// Render the links page: a `.page-header` and a `.links-list` of link items.
pub fn view(links: List(Link)) -> Element(msg) {
  html.div([], [
    html.div([attribute.class("page-header")], [html.text("Links")]),
    html.main([], [
      html.ul([attribute.class("links-list")], list.map(links, view_link)),
    ]),
  ])
}

fn view_link(link: Link) -> Element(msg) {
  html.li([attribute.class("link-item")], [
    html.a(
      [
        attribute.href(link.url),
        attribute.target("_blank"),
        attribute.rel("noopener"),
      ],
      [
        html.h2([attribute.class("link-title")], [html.text(link.title)]),
        html.p([attribute.class("link-description")], [
          html.text(link.description),
        ]),
      ],
    ),
  ])
}
