//// Content model for a single post, mirroring apollo's TOML frontmatter.
////
//// The build pipeline (`content/loader.gleam`) produces these from
//// `content/posts/*.md` files at build time (markdown body rendered to HTML
//// via mork, TOML frontmatter parsed for metadata), following the same pattern
//// as the Lustre `01-routing` example.

import gleam/dict
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string

/// A single entry in a post's table of contents. apollo generates up to three
/// levels (h1, h2, h3) from the markdown headings; arata mirrors that with a
/// recursive `children` list. The `id` is the heading's HTML `id` attribute,
/// which the TOC links to via `#id` anchors.
pub type TocEntry {
  TocEntry(id: String, title: String, children: List(TocEntry))
}

/// A blog post.
pub type Post {
  Post(
    slug: String,
    title: String,
    /// ISO-8601 publication date string, e.g. `"2026-01-15"`.
    date: String,
    /// Optional ISO-8601 last-updated date; rendered as `:: Updated on …`.
    updated: Option(String),
    /// Short description shown in the post list and used for SEO meta.
    description: String,
    /// Rendered HTML body (output of the markdown pipeline).
    body: String,
    /// Table of contents extracted from the body's headings.
    toc: List(TocEntry),
    tags: List(String),
    /// Draft posts are labelled `DRAFT` in the list and on the page.
    draft: Bool,
    /// Optional `tl;dr` summary shown in a box above the body.
    tldr: Option(String),
    /// Word count of the body; shown in the meta row when non-zero.
    word_count: Int,
    /// Reading time in minutes; shown in the meta row when non-zero.
    reading_time: Int,
  )
}

/// Find the first post in `posts` whose slug matches `slug`. Used by the
/// single-post route to look up the post to render.
pub fn find_by_slug(posts: List(Post), slug: String) -> Result(Post, Nil) {
  list.find(posts, fn(post) { post.slug == slug })
}

/// One entry in the tag index: the tag name and the posts that carry it.
pub type TagEntry {
  TagEntry(name: String, posts: List(Post))
}

/// Build a tag index from a list of posts: one `TagEntry` per unique tag,
/// sorted alphabetically by name. Each entry's `posts` list preserves the
/// original (newest-first) order. Used by the `/tags` index page and the
/// `/tags/<tag>` single-tag page.
pub fn tag_index(posts: List(Post)) -> List(TagEntry) {
  posts
  |> list.fold(dict.new(), fn(acc, post) {
    list.fold(post.tags, acc, fn(acc, tag) {
      dict.insert(acc, tag, [post, ..dict.get(acc, tag) |> result.unwrap([])])
    })
  })
  |> dict.to_list
  |> list.map(fn(entry) {
    let #(name, tag_posts) = entry
    TagEntry(name:, posts: list.reverse(tag_posts))
  })
  |> list.sort(by: fn(a, b) { string.compare(a.name, b.name) })
}

/// Find the tag entry for `name`, or `Error(Nil)` if no post has that tag.
pub fn find_tag(entries: List(TagEntry), name: String) -> Result(TagEntry, Nil) {
  list.find(entries, fn(entry) { entry.name == name })
}
