//// Content model for a single post, mirroring apollo's TOML frontmatter.
////
//// The markdown-to-HTML build pipeline (ROADMAP Phase 17) will produce these
//// from `content/*.md` files at build time. For now, sample posts are authored
//// directly as Gleam constants with pre-rendered HTML bodies (see
//// `data/sample_content.gleam`), following the same pattern as the Lustre
//// `01-routing` example.

import gleam/list

/// A blog post.
pub type Post {
  Post(
    slug: String,
    title: String,
    /// ISO-8601 publication date string, e.g. `"2025-01-15"`.
    date: String,
    /// Short description shown in the post list and used for SEO meta.
    description: String,
    /// Rendered HTML body (output of the markdown pipeline).
    body: String,
    tags: List(String),
    /// Draft posts are labelled `DRAFT` in the list and on the page.
    draft: Bool,
  )
}

/// Find the first post in `posts` whose slug matches `slug`. Used by the
/// single-post route to look up the post to render.
pub fn find_by_slug(posts: List(Post), slug: String) -> Result(Post, Nil) {
  list.find(posts, fn(post) { post.slug == slug })
}
