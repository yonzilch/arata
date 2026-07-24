//// Tests for the feed and sitemap generators.

import data/post.{type Post, Post}
import data/site.{type SiteMeta, AnalyticsDisabled, CommentsDisabled, SiteMeta}
import gleam/option.{None}
import gleam/string
import gleeunit
import gleeunit/should

import build/feeds
import config

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

fn sample_posts() -> List(Post) {
  [
    Post(
      slug: "first",
      title: "First Post",
      date: "2026-01-01",
      updated: None,
      description: "The first post.",
      body: "",
      toc: [],
      tags: [],
      draft: False,
      tldr: None,
      word_count: 0,
      reading_time: 0,
    ),
    Post(
      slug: "second",
      title: "Second Post",
      date: "2026-01-02",
      updated: None,
      description: "The second post.",
      body: "",
      toc: [],
      tags: [],
      draft: False,
      tldr: None,
      word_count: 0,
      reading_time: 0,
    ),
  ]
}

fn atom_feed(posts: List(Post)) -> String {
  feeds.atom_feed(sample_site(), posts, "/atom.xsl", config.Full)
}

fn rss_feed(posts: List(Post)) -> String {
  feeds.rss_feed(sample_site(), posts, "/rss.xsl", config.Full)
}

pub fn atom_feed_has_xml_declaration_test() {
  let feed = atom_feed(sample_posts())
  string.starts_with(feed, "<?xml version=\"1.0\"") |> should.be_true()
}

pub fn atom_feed_has_stylesheet_pi_test() {
  let feed = atom_feed(sample_posts())

  string.contains(
    feed,
    "<?xml-stylesheet type=\"text/xsl\" href=\"/atom.xsl\"?>",
  )
  |> should.be_true()
}

pub fn atom_feed_omits_stylesheet_pi_when_href_empty_test() {
  let feed = feeds.atom_feed(sample_site(), sample_posts(), "", config.Full)

  string.contains(feed, "<?xml-stylesheet") |> should.be_false()
}

pub fn atom_feed_has_feed_element_test() {
  let feed = atom_feed(sample_posts())
  string.contains(feed, "<feed xmlns=\"http://www.w3.org/2005/Atom\">")
  |> should.be_true()
}

pub fn atom_feed_has_site_title_test() {
  let feed = atom_feed(sample_posts())
  string.contains(feed, "<title>Test Site</title>") |> should.be_true()
}

pub fn atom_feed_has_site_subtitle_test() {
  let feed = atom_feed(sample_posts())
  string.contains(feed, "<subtitle>A test site.</subtitle>") |> should.be_true()
}

pub fn atom_feed_has_entries_test() {
  let feed = atom_feed(sample_posts())
  string.contains(feed, "<entry>") |> should.be_true()
  string.contains(feed, "First Post") |> should.be_true()
  string.contains(feed, "Second Post") |> should.be_true()
}

pub fn rss_feed_has_xml_declaration_test() {
  let feed = rss_feed(sample_posts())
  string.starts_with(feed, "<?xml version=\"1.0\"") |> should.be_true()
}

pub fn rss_feed_has_stylesheet_pi_test() {
  let feed = rss_feed(sample_posts())

  string.contains(
    feed,
    "<?xml-stylesheet type=\"text/xsl\" href=\"/rss.xsl\"?>",
  )
  |> should.be_true()
}

pub fn rss_feed_omits_stylesheet_pi_when_href_empty_test() {
  let feed = feeds.rss_feed(sample_site(), sample_posts(), "", config.Full)

  string.contains(feed, "<?xml-stylesheet") |> should.be_false()
}

pub fn rss_feed_has_rss_element_test() {
  let feed = rss_feed(sample_posts())
  string.contains(feed, "<rss version=\"2.0\"") |> should.be_true()
}

pub fn rss_feed_has_items_test() {
  let feed = rss_feed(sample_posts())
  string.contains(feed, "<item>") |> should.be_true()
  string.contains(feed, "First Post") |> should.be_true()
}

pub fn sitemap_has_urlset_test() {
  let sitemap = feeds.sitemap(sample_site(), sample_posts(), ["about"])
  string.starts_with(sitemap, "<?xml version=\"1.0\"") |> should.be_true()
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
  string.contains(sitemap, "https://example.com/about") |> should.be_true()
  string.contains(sitemap, "https://example.com</loc>") |> should.be_true()
}

pub fn xml_escapes_special_chars_test() {
  let site =
    SiteMeta(
      ..sample_site(),
      title: "A & B <script>",
      description: "Quote \" test",
      analytics: AnalyticsDisabled,
      comments: CommentsDisabled,
      fediverse_creator: None,
    )

  let feed = feeds.rss_feed(site, [], "/rss.xsl", config.Full)

  string.contains(feed, "&amp;") |> should.be_true()
  string.contains(feed, "&lt;script&gt;") |> should.be_true()
  string.contains(feed, "&quot;") |> should.be_true()
}
