//// Post list view: renders a chronological, paginated list of posts,
//// mirroring apollo's `templates/section.html` and the `list_post` /
//// `list_posts` macros in `templates/macros/macros.html`.
////
//// apollo wraps the list in `<main class="post-list"><ul>...</ul></main>` and
//// follows it with a `<ul class="pagination">` containing Prev/Next links only
//// (no page numbers). Each list item is a `.list-item` whose `.post-header`
//// links to the post and whose `.post-content` carries the description. Draft
//// posts get a `.draft-label` badge after the title.
////
//// `posts` is assumed to be newest-first (see `data/sample_content`); the
//// caller (Phase 17's markdown pipeline) is responsible for sorting. We slice
//// `posts` by `current_page` and `per_page` and render the visible slice.

import data/post.{type Post}
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import route

/// Render the paginated post list.
///
/// `posts` is the full list (newest first); `current_page` is 1-indexed;
/// `per_page` is the page size. The view computes the slice
/// `[start .. start + per_page)` where `start = (current_page - 1) * per_page`,
/// renders each post via `view_list_item`, and renders Prev/Next pagination
/// links via `view_pagination`.
pub fn view(posts: List(Post), current_page: Int, per_page: Int) -> Element(msg) {
  let total = list.length(posts)
  let start = current_page * per_page - per_page
  let page_posts =
    posts
    |> list.drop(start)
    |> list.take(per_page)
  // Prev link is shown when we're past the first page; Next link is shown
  // when there are more posts after the current page slice.
  let has_prev = current_page > 1
  let has_next = start + per_page < total

  html.div([], [
    html.div([attribute.class("page-header")], [html.text("Posts")]),
    html.main([attribute.class("post-list")], [
      html.ul([], list.map(page_posts, view_list_item)),
    ]),
    view_pagination(current_page, has_prev, has_next),
  ])
}

// LIST ITEM --------------------------------------------------------------------

/// Render one post as a `.list-item`, mirroring apollo's `list_post` macro.
///
/// The `.post-header` is an `<a>` linking to the single-post route so modem
/// intercepts the click for client-side navigation. Inside it, a `.title`
/// span carries the title (plus a `.draft-label` badge for drafts) and a
/// `.meta` span carries the publication `<time>`. The `.post-content` div
/// below carries the description.
fn view_list_item(post: Post) -> Element(msg) {
  html.li([attribute.class("list-item")], [
    html.a([attribute.class("post-header"), route.href(route.Post(post.slug))], [
      html.span([attribute.class("title")], view_title(post)),
      html.span([attribute.class("meta")], [
        html.time([attribute.datetime(post.date)], [html.text(post.date)]),
      ]),
    ]),
    html.div([attribute.class("post-content")], [html.text(post.description)]),
  ])
}

/// The title text, optionally followed by a DRAFT badge.
fn view_title(post: Post) -> List(Element(msg)) {
  case post.draft {
    True -> [
      html.text(post.title),
      html.span([attribute.class("draft-label")], [html.text("DRAFT")]),
    ]
    False -> [html.text(post.title)]
  }
}

// PAGINATION -------------------------------------------------------------------

/// Render the Prev/Next pagination. apollo emits a `<ul class="pagination">`
/// with at most two items: Prev (linking to `Posts(current_page - 1)`) and
/// Next (linking to `Posts(current_page + 1)`). Each is conditional.
fn view_pagination(
  current_page: Int,
  has_prev: Bool,
  has_next: Bool,
) -> Element(msg) {
  let prev_item = case has_prev {
    True -> [
      html.li([], [
        html.a([route.href(route.Posts(current_page - 1))], [
          html.text("\u{2190} Prev"),
        ]),
      ]),
    ]
    False -> []
  }
  let next_item = case has_next {
    True -> [
      html.li([], [
        html.a([route.href(route.Posts(current_page + 1))], [
          html.text("Next \u{2192}"),
        ]),
      ]),
    ]
    False -> []
  }
  html.ul([attribute.class("pagination")], list.append(prev_item, next_item))
}
