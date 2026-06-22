//// Content model for a single post, mirroring apollo's TOML frontmatter.
////
//// The markdown-to-HTML build pipeline (ROADMAP Phase 17) will produce these
//// from `content/*.md` files at build time. For now, sample posts are authored
//// directly as Gleam constants with pre-rendered HTML bodies (see
//// `data/sample_content.gleam`), following the same pattern as the Lustre
//// `01-routing` example.

import gleam/list
import gleam/option.{type Option}

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
    /// ISO-8601 publication date string, e.g. `"2025-01-15"`.
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
