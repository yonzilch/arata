//// Single post view: renders a post's header, meta row, optional tl;dr box,
//// body, and tags, mirroring apollo's `templates/page.html` template.
////
//// apollo's page template wraps everything in `<main><article><div
//// class="title">...</div>...<section class="body">...</section></article></main>`.
//// arata reproduces the same `.page-header` / `.meta` / `.tldr` / `.body` /
//// `.post-tags` classes. The meta row carries the publication date, optional
//// updated date, word count, and reading time — matching apollo's conditional
//// meta fields. The table of contents is rendered separately in the
//// `.right-content` sidebar (see `view/toc.gleam`), not inside this view.
////
//// The post body is pre-rendered HTML from the content pipeline (Phase 17),
//// so we inject it verbatim with `lustre/element.unsafe_raw_html`. The body
//// is trusted: it is produced from our own markdown sources, not user input.

import data/markdown
import data/post.{type Post}
import data/site.{type CommentsConfig}
import gleam/int
import gleam/list
import gleam/option.{type Option}
import lustre/attribute
import lustre/element.{type Element, none, unsafe_raw_html}
import lustre/element/html
import route
import view/comments

/// Render a single post.
///
/// Structure:
///   <main>
///     <article>
///       <div class="page-header">{title} [<span class="draft-label">DRAFT</span>]</div>
///       <div class="meta">Posted on <time>...</time> :: Updated on ... :: N Words :: M Min Read</div>
///       <div class="tldr"><strong>tl;dr:</strong> ...</div>     (optional)
///       <section class="body">{body HTML verbatim}</section>
///       <div class="post-tags">...</div>
///     </article>
///   </main>
///
/// The title uses a `<div>` (not `<h1>`) to match apollo's `page_header`
/// macro exactly: the global `h1::before { content: "# " }` rule would
/// otherwise prepend a `#` to the title. The `.page-header` class supplies
/// the 2.5em header typography.
pub fn view(post: Post, comments_config: CommentsConfig) -> Element(msg) {
  html.main([], [
    html.article([], [
      html.div([attribute.class("title")], [
        html.div([attribute.class("page-header")], view_title(post)),
        view_meta(post),
      ]),
      view_tldr(post.tldr),
      unsafe_raw_html(
        "",
        "section",
        [attribute.class("body")],
        markdown.to_html(post.body),
      ),
      view_tags(post.tags),
    ]),
    comments.view(comments_config, post.slug),
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

/// The meta row: publication date, optional updated date, optional word count
/// and reading time. apollo separates fields with ` :: `; arata does the same.
/// Word count and reading time are shown only when non-zero (the build pipeline
/// always sets them; the sample content sets them to exercise the row).
fn view_meta(post: Post) -> Element(msg) {
  let posted = [
    html.text("Posted on "),
    html.time([], [html.text(post.date)]),
  ]
  let parts = list.append(posted, view_meta_updated(post.updated))
  let parts = case post.word_count > 0 {
    True ->
      list.append(parts, [
        html.text(" :: "),
        html.text(int.to_string(post.word_count)),
        html.text(" Words"),
      ])
    False -> parts
  }
  let parts = case post.reading_time > 0 {
    True ->
      list.append(parts, [
        html.text(" :: "),
        html.time([], [html.text(int.to_string(post.reading_time))]),
        html.text(" Min Read"),
      ])
    False -> parts
  }
  html.div([attribute.class("meta")], parts)
}

/// The optional `:: Updated on <time>...</time>` segment of the meta row.
fn view_meta_updated(updated: Option(String)) -> List(Element(msg)) {
  case updated {
    option.Some(date) -> [
      html.text(" :: Updated on "),
      html.time([], [html.text(date)]),
    ]
    option.None -> []
  }
}

/// The optional `.tldr` box shown above the body when the post has a `tldr`.
fn view_tldr(tldr: Option(String)) -> Element(msg) {
  case tldr {
    option.Some(text) ->
      html.div([attribute.class("tldr")], [
        html.strong([], [html.text("tl;dr: ")]),
        html.text(text),
      ])
    option.None -> none()
  }
}

/// Render the post's tags as a `.post-tags` row. Each tag links to its
/// taxonomy page via `route.href(route.Tag(tag))` so modem intercepts the
/// click. Returns `element.none()` when the post has no tags.
fn view_tags(tags: List(String)) -> Element(msg) {
  case tags {
    [] -> none()
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
