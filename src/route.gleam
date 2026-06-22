//// Routing: maps browser URLs to arata's internal `Route` type and back.
////
//// Patterned after the `01-routing` Lustre example, using `modem` for
//// client-side navigation over the History API. `parse_route` turns a `Uri`
//// into a typed `Route`, and `href` turns a `Route` back into an `href`
//// attribute for `<a>` elements. The two functions must stay in sync so every
//// internal link round-trips through `parse_route` to the same `Route`.
////
//// URL scheme (mirrors apollo's content layout):
////
////   `/`                  -> Home
////   `/posts`             -> Posts(1)        (section index, first page)
////   `/posts/page/{n}`    -> Posts(n)        (paginated section index)
////   `/posts/{slug}`      -> Post(slug)
////   `/projects`          -> Projects        (section index)
////   `/projects/{slug}`   -> Page(slug)      (project detail renders as a page)
////   `/links`             -> Links           (friend links index)
////   `/tags`              -> Tags            (taxonomy index)
////   `/tags/{name}`       -> Tag(name)
////   `/{slug}`            -> Page(slug)      (standalone page, e.g. /about)
////   anything else        -> NotFound(uri)

import gleam/int
import gleam/uri.{type Uri}
import lustre/attribute.{type Attribute}

/// The set of pages arata can render. One variant per apollo page template.
pub type Route {
  Home
  /// The paginated post list. `page` is 1-indexed.
  Posts(page: Int)
  Post(slug: String)
  Projects
  Links
  Tags
  Tag(name: String)
  Page(slug: String)
  /// A URI we could not match. Kept so we can log it or hint at a typo. Note
  /// that `NotFound` cannot round-trip through `href` (its URL is a placeholder
  /// `/404`); every other variant does.
  NotFound(uri: Uri)
}

/// Parse a browser URI into a `Route`.
///
/// Section indices (`/posts`, `/projects`, `/links`, `/tags`) are matched
/// before single-segment standalone pages so that e.g. `/posts` is `Posts(1)`
/// and not `Page("posts")`. The paginated index `/posts/page/{n}` is matched
/// before single-post `/posts/{slug}` so the literal segment `"page"` is
/// reserved. Detail pages under `/projects/` parse as `Page(slug)` — apollo
/// renders them as `page.html`. (`/links` has no detail pages.)
pub fn parse_route(uri: Uri) -> Route {
  case uri.path_segments(uri.path) {
    [] | [""] -> Home

    // /posts and /posts/page/{n} — paginated section index.
    ["posts"] -> Posts(1)
    ["posts", "page", page] ->
      case int.parse(page) {
        Ok(page) -> Posts(page)
        Error(_) -> NotFound(uri:)
      }

    // /posts/{slug} — single post.
    ["posts", slug] -> Post(slug)

    ["projects"] -> Projects
    ["projects", slug] -> Page(slug:)
    ["links"] -> Links
    ["tags"] -> Tags
    ["tags", name] -> Tag(name:)

    // Any other single segment is a standalone page (e.g. /about, /404).
    [slug] -> Page(slug:)

    // Anything with two or more segments that didn't match above is unknown.
    _ -> NotFound(uri:)
  }
}

/// Serialise a `Route` back into an `href` attribute for `<a>` elements.
///
/// Must stay in sync with `parse_route`. For every `Route` produced by
/// `parse_route` except `NotFound`, `parse_route(href_url(route)) == route`.
/// `NotFound` is by definition a non-matching URI, so its `href` is a
/// placeholder (`/404`) that parses to `Page("404")` — this is intentional and
/// matches the lustre `01-routing` example's behaviour.
pub fn href(route: Route) -> Attribute(message) {
  attribute.href(href_url(route))
}

/// The URL string a `Route` serialises to. Exposed so other modules can build
/// links without going through the `Attribute` type (e.g. for `modem.push`).
pub fn href_url(route: Route) -> String {
  case route {
    Home -> "/"
    Posts(1) -> "/posts"
    Posts(page) -> "/posts/page/" <> int.to_string(page)
    Post(slug) -> "/posts/" <> slug
    Projects -> "/projects"
    Links -> "/links"
    Tags -> "/tags"
    Tag(name) -> "/tags/" <> name
    Page(slug) -> "/" <> slug
    NotFound(_) -> "/404"
  }
}
