//// Single post view: renders a post's header, meta, body, and tags,
//// mirroring apollo's `templates/page.html` template.
////
//// apollo's page template wraps everything in `<main><article><div
//// class="title">...</div><section class="body">...</section></article></main>`.
//// arata reproduces the same `.page-header` / `.meta` / `.body` / `.post-tags`
//// classes; the optional `.tldr` box (apollo reads it from `page.extra.tldr`)
//// is omitted until the content pipeline exposes that field (Phase 17). Word
//// count, reading time, source-code link, and comments are likewise deferred
//// to later phases — for now the meta row carries only the publication date.
////
//// The post body is pre-rendered HTML from the content pipeline (Phase 17),
//// so we inject it verbatim with `lustre/element.unsafe_raw_html`. The body
//// is trusted: it is produced from our own markdown sources, not user input.

import data/post.{type Post}
import gleam/list
import lustre/attribute
import lustre/element.{type Element, unsafe_raw_html}
import lustre/element/html
import route

/// Render a single post.
///
/// Structure:
///   <main>
///     <div class="page-header">{title} [<span class="draft-label">DRAFT</span>]</div>
///     <div class="meta">Posted on <time datetime="{date}">{date}</time></div>
///     <section class="body">{body HTML verbatim}</section>
///     <div class="post-tags"><a class="tag" href="/tags/{tag}">{tag}</a> ...</div>
///   </main>
///
/// The title uses a `<div>` (not `<h1>`) to match apollo's `page_header`
/// macro exactly: the global `h1::before { content: "# " }` rule would
/// otherwise prepend a `#` to the title. The `.page-header` class supplies
/// the 2.5em header typography.
pub fn view(post: Post) -> Element(msg) {
  html.main([], [
    html.div([attribute.class("page-header")], view_title(post)),
    html.div([attribute.class("meta")], [
      html.text("Posted on "),
      html.time([attribute.datetime(post.date)], [html.text(post.date)]),
    ]),
    unsafe_raw_html("", "section", [attribute.class("body")], post.body),
    view_tags(post.tags),
  ])
}

/// The post title, optionally followed by a DRAFT badge (mirrors apollo's
/// `.draft-label` rendering inside the title block on `page.html`).
fn view_title(post: Post) -> List(Element(msg)) {
  case post.draft {
    True -> [
      html.text(post.title),
      html.span([attribute.class("draft-label")], [html.text("DRAFT")]),
    ]
    False -> [html.text(post.title)]
  }
}

/// Render the post's tags as a `.post-tags` row. Each tag links to its
/// taxonomy page via `route.href(route.Tag(tag))` so modem intercepts the
/// click. Returns `element.none()` when the post has no tags.
fn view_tags(tags: List(String)) -> Element(msg) {
  case tags {
    [] -> element.none()
    _ ->
      html.div(
        [attribute.class("post-tags")],
        list.map(tags, fn(tag) {
          html.a([attribute.class("tag"), route.href(route.Tag(tag))], [
            html.text(tag),
          ])
        }),
      )
  }
}
