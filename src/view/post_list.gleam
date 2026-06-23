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
//// `posts` is assumed to be newest-first (sorted by `content/loader`); we
//// slice `posts` by `current_page` and `per_page` and render the visible
//// slice.
////
//// Fix 6: the `.post-header` is no longer an `<a>` (it's a `<div>`,
//// `role="generic"`); only the title text inside is a link. A page-jump
//// `<input>` is rendered alongside the Prev/Next links so the user can type
//// a page number and jump straight to it.

import data/post.{type Post}
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import route

/// Render the paginated post list.
///
/// `posts` is the full list (newest first); `current_page` is 1-indexed;
/// `per_page` is the page size. The view computes the slice
/// `[start .. start + per_page)` where `start = (current_page - 1) * per_page`,
/// renders each post via `view_list_item`, and renders Prev/Next pagination
/// links (plus the page-jump input) via `view_pagination`.
///
/// `on_page_jump` is dispatched with the input's value when the user submits
/// the page-jump input (Enter or blur). The caller parses the string to an
/// `Int` and navigates to `Posts(n)`.
pub fn view(
  posts: List(Post),
  current_page: Int,
  per_page: Int,
  on_page_jump: fn(String) -> msg,
) -> Element(msg) {
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
    view_items(page_posts),
    view_pagination(current_page, has_prev, has_next, on_page_jump),
  ])
}

/// Render the bare post list — a `<main class="post-list"><ul>` of `.list-item`
/// entries with no page-header and no pagination. Exposed so the tag-single
/// page (and any other list context) can reuse the same per-item rendering
/// with its own header.
pub fn view_items(posts: List(Post)) -> Element(msg) {
  html.main([attribute.class("post-list")], [
    html.ul([], list.map(posts, view_list_item)),
  ])
}

// LIST ITEM --------------------------------------------------------------------

/// Render one post as a `.list-item`, mirroring apollo's `list_post` macro.
///
/// Fix 6: the `.post-header` is a `<div>` (`role="generic"`, no longer an
/// `<a>`); only the `.title` span inside is wrapped in an `<a>` linking to
/// the single-post route (so modem intercepts the click for client-side
/// navigation). The `.meta` span (with the publication `<time>`) and the
/// `.title` span are siblings. The `.post-content` div below carries the
/// description.
fn view_list_item(post: Post) -> Element(msg) {
  // Fix 3: render the post's tags between the header and the description.
  // When the post has no tags, render `element.none()` so the layout stays
  // flat (no empty wrapper div). Each tag links to its `/tags/<name>` route
  // so modem intercepts the click for client-side navigation.
  let tags_el = case post.tags {
    [] -> element.none()
    _ ->
      html.div(
        [attribute.class("post-list-tags")],
        list.map(post.tags, fn(tag) {
          html.a(
            [attribute.class("post-list-tag"), route.href(route.Tag(tag))],
            [html.text(tag)],
          )
        }),
      )
  }
  html.li([attribute.class("list-item post-card")], [
    html.div([attribute.class("post-header")], [
      html.span([attribute.class("meta")], [
        html.time([attribute.datetime(post.date)], [html.text(post.date)]),
      ]),
      html.a([route.href(route.Post(post.slug))], [
        html.span([attribute.class("title")], view_title(post)),
      ]),
    ]),
    tags_el,
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

/// Render the Prev/Next pagination plus the page-jump input. apollo emits a
/// `<ul class="pagination">` with at most two items: Prev (linking to
/// `Posts(current_page - 1)`) and Next (linking to `Posts(current_page + 1)`).
/// Each is conditional. Fix 6 adds a third `.page-jump` item: a number
/// `<input>` whose `on_change` (fires on Enter/blur) dispatches
/// `on_page_jump(value)`. The jump input is only shown when there's more than
/// one page (i.e. `has_prev` or `has_next`).
fn view_pagination(
  current_page: Int,
  has_prev: Bool,
  has_next: Bool,
  on_page_jump: fn(String) -> msg,
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
  // The page-jump input is only rendered when there's more than one page;
  // with a single page there's nowhere to jump to.
  let jump_item = case has_prev || has_next {
    True -> [
      html.li([attribute.class("page-jump")], [
        html.input([
          attribute.type_("number"),
          attribute.attribute("min", "1"),
          attribute.attribute("step", "1"),
          attribute.attribute("placeholder", "Page"),
          attribute.attribute("aria-label", "Jump to page"),
          event.on_change(on_page_jump),
        ]),
      ]),
    ]
    False -> []
  }
  html.ul(
    [attribute.class("pagination")],
    list.append(list.append(prev_item, next_item), jump_item),
  )
}
