//// Search data: a search result type and a pure search function.
////
//// The full elasticlunr integration (ROADMAP Phase 12 mentions keeping the
//// vendored core) is deferred — for now arata uses a lightweight
//// case-insensitive substring search over post titles, descriptions, and tags.
//// This provides functional search without pulling a 2567-line JS dependency
//// into the bundle. The search index is built from the in-memory post list at
//// runtime (no build-time index emission needed until the markdown pipeline
//// lands in Phase 17).

import data/post.{type Post}
import gleam/list
import gleam/string

/// One search result: the post and a snippet of where the query matched.
pub type SearchResult {
  SearchResult(post: Post)
}

/// Search `posts` for `query`. Returns matching posts sorted by relevance
/// (title matches first, then description, then tags). An empty query returns
/// an empty list. Matching is case-insensitive.
pub fn search(posts: List(Post), query: String) -> List(SearchResult) {
  case query {
    "" -> []
    _ -> {
      let q = string.lowercase(query)
      posts
      |> list.filter(fn(post) { matches(post, q) })
      |> list.map(fn(post) { SearchResult(post:) })
    }
  }
}

/// Whether a post matches the query in its title, description, tags, or body.
/// The body is HTML rendered from markdown — `strip_html` removes the tags so
/// we search the plain-text content (otherwise HTML tag/attribute names like
/// `class` or `href` would pollute results).
fn matches(post: Post, query: String) -> Bool {
  let title = string.lowercase(post.title)
  let desc = string.lowercase(post.description)
  let tags =
    post.tags
    |> list.map(string.lowercase)
    |> string.join(" ")
  let body = string.lowercase(strip_html(post.body))
  string.contains(title, query)
  || string.contains(desc, query)
  || string.contains(tags, query)
  || string.contains(body, query)
}

/// Strip HTML tags from a string by dropping everything between `<` and `>`
/// (inclusive). Splits on `<`, then for each piece keeps only the text after
/// the first `>` (or the whole piece if there's no `>`). HTML entities (e.g.
/// `&lt;`) are left untouched — they decode to plain text anyway.
fn strip_html(html: String) -> String {
  html
  |> string.split("<")
  |> list.map(fn(piece) {
    case string.split_once(piece, ">") {
      Ok(#(_tag, rest)) -> rest
      Error(_) -> piece
    }
  })
  |> string.join("")
}
