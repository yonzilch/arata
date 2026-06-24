//// Homepage view with optional latest-posts and aratafetch blocks.

import data/page.{type Page}
import data/post.{type Post}
import gleam/int
import gleam/list
import gleam/option
import lustre/attribute
import lustre/element.{type Element, none, unsafe_raw_html}
import lustre/element/html

/// Render the homepage.
///
/// Layout order:
///   1. homepage markdown body
///   2. optional latest-posts section
///   3. optional aratafetch section
pub fn view(
  home: Page,
  posts: List(Post),
  latest_posts_enabled: Bool,
  latest_posts_count: Int,
  aratafetch_enabled: Bool,
  aratafetch_view: Element(msg),
) -> Element(msg) {
  html.main([], [
    html.article([], [
      html.section([attribute.class("body")], [
        html.div([attribute.class("page-header")], [
          html.text(home.title),
          ..view_subtitle(home.subtitle)
        ]),

        // Markdown body
        unsafe_raw_html("", "div", [], home.body),

        // Latest posts
        view_latest_posts(latest_posts_enabled, posts, latest_posts_count),

        // aratafetch
        view_aratafetch(aratafetch_enabled, aratafetch_view),
      ]),
    ]),
  ])
}

/// Conditionally render homepage latest posts.
///
/// Invariants:
///   - disabled -> renders nothing
///   - count <= 0 -> renders nothing
///   - empty post list -> renders nothing
fn view_latest_posts(
  enabled: Bool,
  posts: List(Post),
  count: Int,
) -> Element(msg) {
  case enabled {
    False -> none()

    True -> {
      let safe_count = int.max(count, 0)
      let latest = list.take(posts, safe_count)

      case latest {
        [] -> none()

        _ ->
          html.section([attribute.class("home-latest-posts")], [
            html.div(
              [attribute.class("home-latest-posts-list")],
              list.map(latest, view_latest_post),
            ),
          ])
      }
    }
  }
}

fn view_latest_post(post: Post) -> Element(msg) {
  html.div([attribute.class("home-latest-post")], [
    html.span([attribute.class("home-latest-post-date")], [
      html.text(post.date),
    ]),
    html.a(
      [
        attribute.class("home-latest-post-title"),
        attribute.href("/posts/" <> post.slug),
      ],
      [
        html.text(post.title),
      ],
    ),
  ])
}

/// Conditionally render aratafetch.
///
/// Invariant:
///   - disabled -> renders nothing (layout identical to pre-feature)
fn view_aratafetch(
  enabled: Bool,
  aratafetch_view: Element(msg),
) -> Element(msg) {
  case enabled {
    True -> aratafetch_view

    False -> none()
  }
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
