//// Feed and sitemap generators: pure functions that produce XML strings for
//// `atom.xml`, `rss.xml`, and `sitemap.xml`, mirroring Zola's built-in feed
//// and sitemap emission.
////
//// These are normally called by the build pipeline (Phase 17) to write the
//// files to `dist/`. For now they are pure functions that return XML strings,
//// so they can be tested and used by any future build step.

import data/post.{type Post}
import data/site.{type SiteMeta}
import gleam/list
import gleam/string

/// Generate an Atom 1.0 feed (`atom.xml`) from the site metadata and posts.
pub fn atom_feed(site: SiteMeta, posts: List(Post)) -> String {
  let entries =
    posts
    |> list.map(fn(post) { "    <entry>
        <title>" <> xml_escape(post.title) <> "</title>
        <link href=\"" <> site.base_url <> "/posts/" <> post.slug <> "\"/>
        <id>" <> site.base_url <> "/posts/" <> post.slug <> "</id>
        <updated>" <> post.date <> "T00:00:00Z</updated>
        <summary>" <> xml_escape(post.description) <> "</summary>
    </entry>" })
    |> string.join("\n")

  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
  <> "<feed xmlns=\"http://www.w3.org/2005/Atom\">\n"
  <> "    <title>"
  <> xml_escape(site.title)
  <> "</title>\n"
  <> "    <link href=\""
  <> site.base_url
  <> "/atom.xml\" rel=\"self\"/>\n"
  <> "    <link href=\""
  <> site.base_url
  <> "\"/>\n"
  <> "    <id>"
  <> site.base_url
  <> "</id>\n"
  <> "    <updated>"
  <> case list.first(posts) {
    Ok(post) -> post.date
    Error(_) -> "2026-01-01"
  }
  <> "T00:00:00Z</updated>\n"
  <> entries
  <> "\n</feed>"
}

/// Generate an RSS 2.0 feed (`rss.xml`) from the site metadata and posts.
pub fn rss_feed(site: SiteMeta, posts: List(Post)) -> String {
  let items =
    posts
    |> list.map(fn(post) { "        <item>
            <title>" <> xml_escape(post.title) <> "</title>
            <link>" <> site.base_url <> "/posts/" <> post.slug <> "</link>
            <guid>" <> site.base_url <> "/posts/" <> post.slug <> "</guid>
            <pubDate>" <> post.date <> "T00:00:00Z</pubDate>
            <description>" <> xml_escape(post.description) <> "</description>
        </item>" })
    |> string.join("\n")

  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
  <> "<rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\">\n"
  <> "    <channel>\n"
  <> "        <title>"
  <> xml_escape(site.title)
  <> "</title>\n"
  <> "        <link>"
  <> site.base_url
  <> "</link>\n"
  <> "        <description>"
  <> xml_escape(site.description)
  <> "</description>\n"
  <> "        <atom:link href=\""
  <> site.base_url
  <> "/rss.xml\" rel=\"self\" type=\"application/rss+xml\"/>\n"
  <> items
  <> "\n    </channel>\n</rss>"
}

/// Generate a `sitemap.xml` from the site metadata and all known URLs.
pub fn sitemap(
  site: SiteMeta,
  posts: List(Post),
  pages: List(String),
) -> String {
  let post_urls =
    posts
    |> list.map(fn(post) { "    <url>
        <loc>" <> site.base_url <> "/posts/" <> post.slug <> "</loc>
        <lastmod>" <> post.date <> "</lastmod>
    </url>" })
  let page_urls =
    pages
    |> list.map(fn(slug) { "    <url>
        <loc>" <> site.base_url <> "/" <> slug <> "</loc>
    </url>" })
  let all_urls = list.append(post_urls, page_urls)

  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
  <> "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n"
  <> "    <url>\n        <loc>"
  <> site.base_url
  <> "</loc>\n    </url>\n"
  <> string.join(all_urls, "\n")
  <> "\n</urlset>"
}

/// Escape XML special characters.
fn xml_escape(s: String) -> String {
  s
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("\"", "&quot;")
  |> string.replace("'", "&apos;")
}
