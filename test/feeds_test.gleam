//// Tests for the Atom, RSS, and sitemap generators.
////
//// These tests cover:
////
////   - Atom and RSS document structure;
////   - optional browser stylesheet processing instructions;
////   - full-content and summary-only feed modes;
////   - XML escaping of metadata and rendered HTML;
////   - Atom RFC 3339 and RSS RFC 822 publication dates;
////   - exclusion of drafts and posts without publication dates;
////   - graceful handling of missing summaries;
////   - preservation of eligible post ordering;
////   - sitemap structure and canonical URLs.
////
//// `Disabled` is a build-pipeline concern. The feed generators reject that
//// mode and must not be called when feed generation is disabled.

import build/feeds
import config
import data/post.{type Post, Post}
import data/site.{type SiteMeta, AnalyticsDisabled, CommentsDisabled, SiteMeta}
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import gleeunit/should

pub fn main() -> Nil {
  gleeunit.main()
}

fn sample_site() -> SiteMeta {
  SiteMeta(
    base_url: "https://example.com",
    title: "Test Site",
    description: "A test site.",
    analytics: AnalyticsDisabled,
    comments: CommentsDisabled,
    fediverse_creator: None,
    rss_enabled: True,
  )
}

fn first_post() -> Post {
  Post(
    slug: "first",
    title: "First Post",
    date: "2026-01-01",
    updated: None,
    description: "The first post.",
    body: "<p>The complete first post.</p>",
    toc: [],
    tags: [],
    draft: False,
    tldr: None,
    word_count: 4,
    reading_time: 1,
  )
}

fn second_post() -> Post {
  Post(
    slug: "second",
    title: "Second Post",
    date: "2026-01-02",
    updated: Some("2026-01-03"),
    description: "The second post.",
    body: "<p>The complete second post.</p>",
    toc: [],
    tags: [],
    draft: False,
    tldr: None,
    word_count: 4,
    reading_time: 1,
  )
}

fn sample_posts() -> List(Post) {
  [
    first_post(),
    second_post(),
  ]
}

fn draft_post() -> Post {
  Post(
    slug: "draft",
    title: "Draft Post",
    date: "2026-01-03",
    updated: None,
    description: "This post is a draft.",
    body: "<p>Draft content must not enter feeds.</p>",
    toc: [],
    tags: [],
    draft: True,
    tldr: None,
    word_count: 6,
    reading_time: 1,
  )
}

fn undated_post() -> Post {
  Post(
    slug: "undated",
    title: "Undated Post",
    date: "",
    updated: None,
    description: "This post has no publication date.",
    body: "<p>Undated content must not enter feeds.</p>",
    toc: [],
    tags: [],
    draft: False,
    tldr: None,
    word_count: 6,
    reading_time: 1,
  )
}

fn post_without_summary() -> Post {
  Post(
    slug: "without-summary",
    title: "Post Without Summary",
    date: "2026-01-04",
    updated: None,
    description: "",
    body: "<p>Complete content without an authored summary.</p>",
    toc: [],
    tags: [],
    draft: False,
    tldr: None,
    word_count: 6,
    reading_time: 1,
  )
}

fn full_atom_feed(posts: List(Post)) -> String {
  feeds.atom_feed(sample_site(), posts, "/atom.xsl", config.Full)
}

fn summary_atom_feed(posts: List(Post)) -> String {
  feeds.atom_feed(sample_site(), posts, "/atom.xsl", config.Summary)
}

fn full_rss_feed(posts: List(Post)) -> String {
  feeds.rss_feed(sample_site(), posts, "/rss.xsl", config.Full)
}

fn summary_rss_feed(posts: List(Post)) -> String {
  feeds.rss_feed(sample_site(), posts, "/rss.xsl", config.Summary)
}

pub fn atom_feed_has_xml_declaration_test() {
  let feed = full_atom_feed(sample_posts())

  string.starts_with(feed, "<?xml version=\"1.0\"")
  |> should.be_true()
}

pub fn atom_feed_has_stylesheet_pi_test() {
  let feed = full_atom_feed(sample_posts())

  string.contains(
    feed,
    "<?xml-stylesheet type=\"text/xsl\" href=\"/atom.xsl\"?>",
  )
  |> should.be_true()
}

pub fn atom_feed_omits_stylesheet_pi_when_href_empty_test() {
  let feed = feeds.atom_feed(sample_site(), sample_posts(), "", config.Full)

  string.contains(feed, "<?xml-stylesheet")
  |> should.be_false()
}

pub fn atom_feed_has_feed_element_test() {
  let feed = full_atom_feed(sample_posts())

  string.contains(feed, "<feed xmlns=\"http://www.w3.org/2005/Atom\">")
  |> should.be_true()
}

pub fn atom_feed_has_site_metadata_test() {
  let feed = full_atom_feed(sample_posts())

  string.contains(feed, "<title>Test Site</title>")
  |> should.be_true()

  string.contains(feed, "<subtitle>A test site.</subtitle>")
  |> should.be_true()

  string.contains(feed, "<id>https://example.com</id>")
  |> should.be_true()
}

pub fn atom_feed_has_self_and_alternate_links_test() {
  let feed = full_atom_feed(sample_posts())

  string.contains(feed, "\"https://example.com/atom.xml\"")
  |> should.be_true()

  string.contains(feed, "\"https://example.com\"")
  |> should.be_true()
}

pub fn atom_feed_has_entries_test() {
  let feed = full_atom_feed(sample_posts())

  string.contains(feed, "<entry>")
  |> should.be_true()

  string.contains(feed, "First Post")
  |> should.be_true()

  string.contains(feed, "Second Post")
  |> should.be_true()
}

pub fn atom_feed_uses_rfc3339_dates_test() {
  let feed = full_atom_feed(sample_posts())

  string.contains(feed, "<published>2026-01-01T00:00:00Z</published>")
  |> should.be_true()

  string.contains(feed, "<updated>2026-01-01T00:00:00Z</updated>")
  |> should.be_true()
}

pub fn atom_full_mode_emits_rendered_content_test() {
  let feed = full_atom_feed(sample_posts())

  string.contains(feed, "<content type=\"html\">")
  |> should.be_true()

  string.contains(feed, "&lt;p&gt;The complete first post.&lt;/p&gt;")
  |> should.be_true()
}

pub fn atom_full_mode_preserves_summary_test() {
  let feed = full_atom_feed(sample_posts())

  string.contains(feed, "<summary type=\"text\">The first post.</summary>")
  |> should.be_true()
}

pub fn atom_summary_mode_omits_rendered_content_test() {
  let feed = summary_atom_feed(sample_posts())

  string.contains(feed, "<summary type=\"text\">The first post.</summary>")
  |> should.be_true()

  string.contains(feed, "<content type=\"html\">")
  |> should.be_false()

  string.contains(feed, "The complete first post.")
  |> should.be_false()
}

pub fn atom_feed_excludes_drafts_test() {
  let feed =
    full_atom_feed([
      first_post(),
      draft_post(),
    ])

  string.contains(feed, "First Post")
  |> should.be_true()

  string.contains(feed, "Draft Post")
  |> should.be_false()

  string.contains(feed, "Draft content must not enter feeds.")
  |> should.be_false()
}

pub fn atom_feed_excludes_posts_without_dates_test() {
  let feed =
    full_atom_feed([
      first_post(),
      undated_post(),
    ])

  string.contains(feed, "First Post")
  |> should.be_true()

  string.contains(feed, "Undated Post")
  |> should.be_false()

  string.contains(feed, "<published>T00:00:00Z</published>")
  |> should.be_false()
}

pub fn atom_feed_handles_missing_summary_test() {
  let feed = full_atom_feed([post_without_summary()])

  string.contains(feed, "<summary type=\"text\"></summary>")
  |> should.be_true()

  string.contains(
    feed,
    "&lt;p&gt;Complete content without an authored summary.&lt;/p&gt;",
  )
  |> should.be_true()
}

pub fn atom_summary_mode_handles_missing_summary_test() {
  let feed = summary_atom_feed([post_without_summary()])

  string.contains(feed, "<summary type=\"text\"></summary>")
  |> should.be_true()

  string.contains(feed, "<content type=\"html\">")
  |> should.be_false()

  string.contains(feed, "Complete content without an authored summary.")
  |> should.be_false()
}

pub fn atom_feed_preserves_post_order_test() {
  let feed =
    full_atom_feed([
      first_post(),
      second_post(),
    ])

  let assert Ok(#(_, after_first)) =
    string.split_once(feed, "<title>First Post</title>")

  string.contains(after_first, "<title>Second Post</title>")
  |> should.be_true()
}

pub fn atom_empty_feed_uses_stable_updated_fallback_test() {
  let feed = full_atom_feed([])

  string.contains(feed, "<updated>2026-01-01T00:00:00Z</updated>")
  |> should.be_true()

  string.contains(feed, "<entry>")
  |> should.be_false()
}

pub fn rss_feed_has_xml_declaration_test() {
  let feed = full_rss_feed(sample_posts())

  string.starts_with(feed, "<?xml version=\"1.0\"")
  |> should.be_true()
}

pub fn rss_feed_has_stylesheet_pi_test() {
  let feed = full_rss_feed(sample_posts())

  string.contains(
    feed,
    "<?xml-stylesheet type=\"text/xsl\" href=\"/rss.xsl\"?>",
  )
  |> should.be_true()
}

pub fn rss_feed_omits_stylesheet_pi_when_href_empty_test() {
  let feed = feeds.rss_feed(sample_site(), sample_posts(), "", config.Full)

  string.contains(feed, "<?xml-stylesheet")
  |> should.be_false()
}

pub fn rss_feed_has_rss_element_test() {
  let feed = full_rss_feed(sample_posts())

  string.contains(feed, "<rss version=\"2.0\"")
  |> should.be_true()
}

pub fn rss_feed_declares_required_namespaces_test() {
  let feed = full_rss_feed(sample_posts())

  string.contains(feed, "xmlns:atom=\"http://www.w3.org/2005/Atom\"")
  |> should.be_true()

  string.contains(
    feed,
    "xmlns:content=\"http://purl.org/rss/1.0/modules/content/\"",
  )
  |> should.be_true()
}

pub fn rss_feed_has_channel_metadata_test() {
  let feed = full_rss_feed(sample_posts())

  string.contains(feed, "<title>Test Site</title>")
  |> should.be_true()

  string.contains(feed, "<link>https://example.com</link>")
  |> should.be_true()

  string.contains(feed, "<description>A test site.</description>")
  |> should.be_true()
}

pub fn rss_feed_has_self_link_test() {
  let feed = full_rss_feed(sample_posts())

  string.contains(feed, "rel=\"self\" type=\"application/rss+xml\"")
  |> should.be_true()

  string.contains(feed, "https://example.com/rss.xml")
  |> should.be_true()
}

pub fn rss_feed_uses_rfc822_dates_test() {
  let feed = full_rss_feed(sample_posts())

  string.contains(feed, "<pubDate>Thu, 01 Jan 2026 00:00:00 GMT</pubDate>")
  |> should.be_true()

  string.contains(feed, "<pubDate>Fri, 02 Jan 2026 00:00:00 GMT</pubDate>")
  |> should.be_true()
}

pub fn rss_feed_uses_permalink_guids_test() {
  let feed = full_rss_feed(sample_posts())

  string.contains(
    feed,
    "<guid isPermaLink=\"true\">https://example.com/posts/first</guid>",
  )
  |> should.be_true()
}

pub fn rss_full_mode_emits_rendered_content_test() {
  let feed = full_rss_feed(sample_posts())

  string.contains(feed, "<content:encoded>")
  |> should.be_true()

  string.contains(feed, "&lt;p&gt;The complete first post.&lt;/p&gt;")
  |> should.be_true()
}

pub fn rss_full_mode_preserves_description_test() {
  let feed = full_rss_feed(sample_posts())

  string.contains(feed, "<description>The first post.</description>")
  |> should.be_true()
}

pub fn rss_summary_mode_omits_rendered_content_test() {
  let feed = summary_rss_feed(sample_posts())

  string.contains(feed, "<description>The first post.</description>")
  |> should.be_true()

  string.contains(feed, "<content:encoded>")
  |> should.be_false()

  string.contains(feed, "The complete first post.")
  |> should.be_false()
}

pub fn rss_feed_excludes_drafts_test() {
  let feed =
    full_rss_feed([
      first_post(),
      draft_post(),
    ])

  string.contains(feed, "First Post")
  |> should.be_true()

  string.contains(feed, "Draft Post")
  |> should.be_false()

  string.contains(feed, "Draft content must not enter feeds.")
  |> should.be_false()
}

pub fn rss_feed_excludes_posts_without_dates_test() {
  let feed =
    full_rss_feed([
      first_post(),
      undated_post(),
    ])

  string.contains(feed, "First Post")
  |> should.be_true()

  string.contains(feed, "Undated Post")
  |> should.be_false()

  string.contains(feed, "<pubDate> 00:00:00 GMT</pubDate>")
  |> should.be_false()
}

pub fn rss_feed_handles_missing_summary_test() {
  let feed = full_rss_feed([post_without_summary()])

  string.contains(feed, "<description></description>")
  |> should.be_true()

  string.contains(
    feed,
    "&lt;p&gt;Complete content without an authored summary.&lt;/p&gt;",
  )
  |> should.be_true()
}

pub fn rss_summary_mode_handles_missing_summary_test() {
  let feed = summary_rss_feed([post_without_summary()])

  string.contains(feed, "<description></description>")
  |> should.be_true()

  string.contains(feed, "<content:encoded>")
  |> should.be_false()

  string.contains(feed, "Complete content without an authored summary.")
  |> should.be_false()
}

pub fn rss_feed_preserves_post_order_test() {
  let feed =
    full_rss_feed([
      first_post(),
      second_post(),
    ])

  let assert Ok(#(_, after_first)) =
    string.split_once(feed, "<title>First Post</title>")

  string.contains(after_first, "<title>Second Post</title>")
  |> should.be_true()
}

pub fn full_feeds_escape_rendered_html_test() {
  let post = Post(..first_post(), body: "<p title=\"A & B\">One 'two'</p>")

  let atom = full_atom_feed([post])
  let rss = full_rss_feed([post])

  let escaped =
    "&lt;p title=&quot;A &amp; B&quot;&gt;One &apos;two&apos;&lt;/p&gt;"

  string.contains(atom, escaped)
  |> should.be_true()

  string.contains(rss, escaped)
  |> should.be_true()

  string.contains(atom, "<p title=\"A & B\">")
  |> should.be_false()

  string.contains(rss, "<p title=\"A & B\">")
  |> should.be_false()
}

pub fn feed_escapes_site_metadata_test() {
  let site =
    SiteMeta(
      ..sample_site(),
      title: "A & B <script>",
      description: "Quote \" test",
      analytics: AnalyticsDisabled,
      comments: CommentsDisabled,
      fediverse_creator: None,
    )

  let atom = feeds.atom_feed(site, [], "/atom.xsl", config.Full)

  let rss = feeds.rss_feed(site, [], "/rss.xsl", config.Full)

  string.contains(atom, "A &amp; B &lt;script&gt;")
  |> should.be_true()

  string.contains(rss, "A &amp; B &lt;script&gt;")
  |> should.be_true()

  string.contains(atom, "Quote &quot; test")
  |> should.be_true()

  string.contains(rss, "Quote &quot; test")
  |> should.be_true()

  string.contains(atom, "<script>")
  |> should.be_false()

  string.contains(rss, "<script>")
  |> should.be_false()
}

pub fn sitemap_has_xml_declaration_and_urlset_test() {
  let sitemap = feeds.sitemap(sample_site(), sample_posts(), ["about"])

  string.starts_with(sitemap, "<?xml version=\"1.0\"")
  |> should.be_true()

  string.contains(
    sitemap,
    "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">",
  )
  |> should.be_true()
}

pub fn sitemap_has_all_urls_test() {
  let sitemap = feeds.sitemap(sample_site(), sample_posts(), ["about"])

  string.contains(sitemap, "https://example.com/posts/first")
  |> should.be_true()

  string.contains(sitemap, "https://example.com/posts/second")
  |> should.be_true()

  string.contains(sitemap, "https://example.com/about")
  |> should.be_true()

  string.contains(sitemap, "https://example.com</loc>")
  |> should.be_true()
}

pub fn sitemap_escapes_urls_test() {
  let site =
    SiteMeta(
      ..sample_site(),
      base_url: "https://example.com/blog?owner=a&lang=en",
    )

  let sitemap = feeds.sitemap(site, [], [])

  string.contains(sitemap, "https://example.com/blog?owner=a&amp;lang=en")
  |> should.be_true()
}
