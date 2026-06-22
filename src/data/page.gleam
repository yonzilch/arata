//// Content model for a standalone page (e.g. /about), mirroring apollo's
//// page frontmatter. Unlike a `Post`, a `Page` has no date, tags, or
//// pagination — just a slug, title, and rendered HTML body. apollo renders
//// these with the same `page.html` template as posts.

import gleam/list
import gleam/option.{type Option}

/// A standalone page.
pub type Page {
  Page(
    slug: String,
    title: String,
    /// Rendered HTML body.
    body: String,
    /// Optional page header subtitle or tagline shown under the title.
    subtitle: Option(String),
  )
}

/// Find a page by slug in a list. Used by the `Page(slug)` route lookup.
pub fn find_by_slug(pages: List(Page), slug: String) -> Result(Page, Nil) {
  list.find(pages, fn(page) { page.slug == slug })
}
