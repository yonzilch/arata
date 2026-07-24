//// Feed and sitemap generators: pure functions that produce XML strings for
//// `atom.xml`, `rss.xml`, and `sitemap.xml`, mirroring Zola's built-in feed
//// and sitemap emission.
////
//// These are normally called by the build pipeline to write the files to
//// `dist/`. The feed generators can attach an XML stylesheet processing
//// instruction so browsers render a readable feed preview while feed readers
//// continue consuming the raw Atom/RSS XML normally.
////
//// Feed entry content follows the resolved `config.FeedMode`:
////
////   - `Full` emits the post summary and complete rendered HTML body;
////   - `Summary` emits the post summary only;
////   - `Disabled` is rejected by the feed renderers because the build pipeline
////     must not invoke them when feed generation is disabled.
////
//// Timestamps follow each format's own convention: Atom's `published` and
//// `updated` use RFC 3339/ISO 8601 (e.g. `2026-01-01T00:00:00Z`), while RSS's
//// `pubDate` uses RFC 822 (e.g. `Thu, 01 Jan 2026 00:00:00 GMT`), per the RSS
//// 2.0 specification.

import config
import data/post.{type Post}
import data/site.{type SiteMeta}
import gleam/int
import gleam/list
import gleam/result
import gleam/string

/// Generate an Atom 1.0 feed (`atom.xml`) from the site metadata and posts.
///
/// `stylesheet_href` is the public href of the XSL stylesheet used when a human
/// opens the feed directly in a browser. Feed readers ignore the processing
/// instruction and consume the XML as usual.
///
/// Pass `""` to omit the stylesheet processing instruction.
///
/// `Full` adds an HTML `content` element containing the complete rendered post
/// body. `Summary` emits only the existing summary element.
///
/// The build pipeline must not call this function with `Disabled`.
pub fn atom_feed(
  site: SiteMeta,
  posts: List(Post),
  stylesheet_href: String,
  mode: config.FeedMode,
) -> String {
  let published_posts = feed_posts(posts)

  let entries =
    published_posts
    |> list.map(fn(post) { atom_entry(site, post, mode) })
    |> string.join("\n")

  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
  <> xml_stylesheet_pi(stylesheet_href)
  <> "<feed xmlns=\"http://www.w3.org/2005/Atom\">\n"
  <> "    <title>"
  <> xml_escape(site.title)
  <> "</title>\n"
  <> "    <subtitle>"
  <> xml_escape(site.description)
  <> "</subtitle>\n"
  <> "    <link href=\""
  <> xml_escape(site_url(site, "/atom.xml"))
  <> "\" rel=\"self\" type=\"application/atom+xml\"/>\n"
  <> "    <link href=\""
  <> xml_escape(trim_trailing_slashes(site.base_url))
  <> "\" rel=\"alternate\" type=\"text/html\"/>\n"
  <> "    <id>"
  <> xml_escape(trim_trailing_slashes(site.base_url))
  <> "</id>\n"
  <> "    <updated>"
  <> feed_updated(published_posts)
  <> "</updated>\n"
  <> entries
  <> "\n</feed>"
}

/// Generate one Atom entry.
fn atom_entry(site: SiteMeta, post: Post, mode: config.FeedMode) -> String {
  let post_url = site_url(site, "/posts/" <> post.slug)

  "    <entry>\n"
  <> "        <title>"
  <> xml_escape(post.title)
  <> "</title>\n"
  <> "        <link href=\""
  <> xml_escape(post_url)
  <> "\" rel=\"alternate\" type=\"text/html\"/>\n"
  <> "        <id>"
  <> xml_escape(post_url)
  <> "</id>\n"
  <> "        <published>"
  <> post_timestamp(post)
  <> "</published>\n"
  <> "        <updated>"
  <> post_timestamp(post)
  <> "</updated>\n"
  <> "        <summary type=\"text\">"
  <> xml_escape(post.description)
  <> "</summary>\n"
  <> atom_content(post, mode)
  <> "    </entry>"
}

/// Render mode-dependent Atom entry content.
///
/// Rendered HTML is XML-escaped because it is text inside an Atom
/// `content type="html"` element. Feed readers decode the XML entities before
/// interpreting the value as HTML.
fn atom_content(post: Post, mode: config.FeedMode) -> String {
  case mode {
    config.Full ->
      "        <content type=\"html\">"
      <> xml_escape(post.body)
      <> "</content>\n"

    config.Summary -> ""

    config.Disabled -> panic as "atom_feed cannot render disabled feed mode"
  }
}

/// Generate an RSS 2.0 feed (`rss.xml`) from the site metadata and posts.
///
/// `stylesheet_href` is the public href of the XSL stylesheet used when a human
/// opens the feed directly in a browser. Feed readers ignore the processing
/// instruction and consume the XML as usual.
///
/// Pass `""` to omit the stylesheet processing instruction.
///
/// `Full` adds a namespaced `content:encoded` element containing the complete
/// rendered post body. `Summary` emits only the existing description element.
///
/// The build pipeline must not call this function with `Disabled`.
pub fn rss_feed(
  site: SiteMeta,
  posts: List(Post),
  stylesheet_href: String,
  mode: config.FeedMode,
) -> String {
  let published_posts = feed_posts(posts)

  let items =
    published_posts
    |> list.map(fn(post) { rss_item(site, post, mode) })
    |> string.join("\n")

  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
  <> xml_stylesheet_pi(stylesheet_href)
  <> "<rss version=\"2.0\"\n"
  <> "  xmlns:atom=\"http://www.w3.org/2005/Atom\"\n"
  <> "  xmlns:content=\"http://purl.org/rss/1.0/modules/content/\">\n"
  <> "    <channel>\n"
  <> "        <title>"
  <> xml_escape(site.title)
  <> "</title>\n"
  <> "        <link>"
  <> xml_escape(trim_trailing_slashes(site.base_url))
  <> "</link>\n"
  <> "        <description>"
  <> xml_escape(site.description)
  <> "</description>\n"
  <> "        <atom:link href=\""
  <> xml_escape(site_url(site, "/rss.xml"))
  <> "\" rel=\"self\" type=\"application/rss+xml\"/>\n"
  <> items
  <> "\n    </channel>\n"
  <> "</rss>"
}

/// Generate one RSS item.
fn rss_item(site: SiteMeta, post: Post, mode: config.FeedMode) -> String {
  let post_url = site_url(site, "/posts/" <> post.slug)

  "        <item>\n"
  <> "            <title>"
  <> xml_escape(post.title)
  <> "</title>\n"
  <> "            <link>"
  <> xml_escape(post_url)
  <> "</link>\n"
  <> "            <guid isPermaLink=\"true\">"
  <> xml_escape(post_url)
  <> "</guid>\n"
  <> "            <pubDate>"
  <> rss_pub_date(post)
  <> "</pubDate>\n"
  <> "            <description>"
  <> xml_escape(post.description)
  <> "</description>\n"
  <> rss_content(post, mode)
  <> "        </item>"
}

/// Render mode-dependent RSS item content.
///
/// The HTML is XML-escaped instead of wrapped in CDATA. This avoids malformed
/// XML when authored content contains the CDATA terminator while preserving the
/// rendered HTML value consumed by feed readers.
fn rss_content(post: Post, mode: config.FeedMode) -> String {
  case mode {
    config.Full ->
      "            <content:encoded>"
      <> xml_escape(post.body)
      <> "</content:encoded>\n"

    config.Summary -> ""

    config.Disabled -> panic as "rss_feed cannot render disabled feed mode"
  }
}

/// Return posts eligible for Atom and RSS output.
///
/// Feed entries require a publication date. Draft posts and posts without a
/// non-empty date remain available to the site but are excluded from feeds,
/// matching Zola's feed behavior.
fn feed_posts(posts: List(Post)) -> List(Post) {
  posts
  |> list.filter(fn(post) { !post.draft && string.trim(post.date) != "" })
}

/// Return the timestamp used for a post entry in Atom's `published` and
/// `updated` elements, in RFC 3339/ISO 8601 format.
///
/// Feed dates retain the current Arata date representation and append the UTC
/// midnight time component.
fn post_timestamp(post: Post) -> String {
  xml_escape(post.date) <> "T00:00:00Z"
}

/// Return the timestamp used for the Atom feed itself.
///
/// The first post remains the source of the feed timestamp, preserving the
/// existing post-order contract. An empty feed uses a stable fallback value.
fn feed_updated(posts: List(Post)) -> String {
  case list.first(posts) {
    Ok(post) -> post_timestamp(post)

    Error(_) -> "2026-01-01T00:00:00Z"
  }
}

/// Return the RSS `pubDate` for a post, in RFC 822 format.
///
/// RSS 2.0 requires RFC 822 dates (e.g. `Sat, 07 Sep 2002 00:00:00 GMT`),
/// unlike Atom's RFC 3339/ISO 8601 dates used by `post_timestamp`. Posts are
/// treated as UTC midnight, matching the existing timestamp contract.
fn rss_pub_date(post: Post) -> String {
  rfc822_date(post.date)
}

/// Format a `YYYY-MM-DD` date as an RFC 822 date-time at UTC midnight.
///
/// Falls back to appending the time and zone directly to the original string
/// when it cannot be parsed as `YYYY-MM-DD`, so a malformed date degrades
/// gracefully instead of crashing the build.
fn rfc822_date(date: String) -> String {
  case parse_ymd(date) {
    Ok(#(year, month, day)) ->
      weekday_abbreviation(weekday_index(year, month, day))
      <> ", "
      <> pad_two_digits(day)
      <> " "
      <> month_abbreviation(month)
      <> " "
      <> int.to_string(year)
      <> " 00:00:00 GMT"

    Error(_) -> xml_escape(date) <> " 00:00:00 GMT"
  }
}

/// Parse a `YYYY-MM-DD` date string into its numeric components.
fn parse_ymd(date: String) -> Result(#(Int, Int, Int), Nil) {
  case string.split(date, "-") {
    [year_str, month_str, day_str] -> {
      use year <- result.try(int.parse(year_str))
      use month <- result.try(int.parse(month_str))
      use day <- result.try(int.parse(day_str))
      Ok(#(year, month, day))
    }

    _ -> Error(Nil)
  }
}

/// Compute the day of the week for a Gregorian calendar date using
/// Sakamoto's algorithm.
///
/// Returns `0` for Sunday through `6` for Saturday.
fn weekday_index(year: Int, month: Int, day: Int) -> Int {
  let adjusted_year = case month < 3 {
    True -> year - 1
    False -> year
  }

  let sum =
    adjusted_year
    + adjusted_year
    / 4
    - adjusted_year
    / 100
    + adjusted_year
    / 400
    + sakamoto_month_offset(month)
    + day

  sum % 7
}

/// Sakamoto's algorithm month offsets, indexed from January.
fn sakamoto_month_offset(month: Int) -> Int {
  case month {
    1 -> 0
    2 -> 3
    3 -> 2
    4 -> 5
    5 -> 0
    6 -> 3
    7 -> 5
    8 -> 1
    9 -> 4
    10 -> 6
    11 -> 2
    12 -> 4
    _ -> 0
  }
}

fn weekday_abbreviation(index: Int) -> String {
  case index {
    0 -> "Sun"
    1 -> "Mon"
    2 -> "Tue"
    3 -> "Wed"
    4 -> "Thu"
    5 -> "Fri"
    6 -> "Sat"
    _ -> "Sun"
  }
}

fn month_abbreviation(month: Int) -> String {
  case month {
    1 -> "Jan"
    2 -> "Feb"
    3 -> "Mar"
    4 -> "Apr"
    5 -> "May"
    6 -> "Jun"
    7 -> "Jul"
    8 -> "Aug"
    9 -> "Sep"
    10 -> "Oct"
    11 -> "Nov"
    12 -> "Dec"
    _ -> "Jan"
  }
}

fn pad_two_digits(value: Int) -> String {
  case value < 10 {
    True -> "0" <> int.to_string(value)
    False -> int.to_string(value)
  }
}

/// Generate a `sitemap.xml` from the site metadata and all known URLs.
pub fn sitemap(
  site: SiteMeta,
  posts: List(Post),
  pages: List(String),
) -> String {
  let post_urls =
    posts
    |> list.map(fn(post) {
      "    <url>\n"
      <> "        <loc>"
      <> xml_escape(site_url(site, "/posts/" <> post.slug))
      <> "</loc>\n"
      <> "        <lastmod>"
      <> xml_escape(post.date)
      <> "</lastmod>\n"
      <> "    </url>"
    })

  let page_urls =
    pages
    |> list.map(fn(slug) {
      "    <url>\n"
      <> "        <loc>"
      <> xml_escape(site_url(site, "/" <> slug))
      <> "</loc>\n"
      <> "    </url>"
    })

  let all_urls = list.append(post_urls, page_urls)

  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
  <> "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n"
  <> "    <url>\n"
  <> "        <loc>"
  <> xml_escape(site.base_url)
  <> "</loc>\n"
  <> "    </url>\n"
  <> string.join(all_urls, "\n")
  <> "\n</urlset>"
}

/// Build an absolute public URL from the canonical site URL and local path.
fn site_url(site: SiteMeta, path: String) -> String {
  trim_trailing_slashes(site.base_url) <> ensure_leading_slash(path)
}

fn ensure_leading_slash(path: String) -> String {
  case path {
    "" -> ""

    _ ->
      case string.starts_with(path, "/") {
        True -> path

        False -> "/" <> path
      }
  }
}

fn trim_trailing_slashes(value: String) -> String {
  case string.ends_with(value, "/") {
    True -> {
      let size = string.length(value)

      value
      |> string.slice(0, size - 1)
      |> trim_trailing_slashes
    }

    False -> value
  }
}

/// Render an XML stylesheet processing instruction.
///
/// The processing instruction must appear after the XML declaration and before
/// the root element. Browsers use it to transform the feed into a readable HTML
/// preview; feed readers normally ignore it.
fn xml_stylesheet_pi(href: String) -> String {
  case string.trim(href) {
    "" -> ""

    href ->
      "<?xml-stylesheet type=\"text/xsl\" href=\""
      <> xml_escape(href)
      <> "\"?>\n"
  }
}

/// Escape XML special characters.
///
/// This function is used for plain XML text, attribute values, and rendered
/// HTML embedded as escaped text in Atom and RSS content elements.
fn xml_escape(value: String) -> String {
  value
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("\"", "&quot;")
  |> string.replace("'", "&apos;")
}
