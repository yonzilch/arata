//// Tests for the routing module: `parse_route` and `href_url` round-trips.

import gleam/uri
import gleeunit
import gleeunit/should

import route.{
  type Route, Home, Links, NotFound, Page, Post, Posts, Projects, Tag, Tags,
}

pub fn main() -> Nil {
  gleeunit.main()
}

// parse_route ----------------------------------------------------------------

fn parse(path: String) -> Route {
  let assert Ok(uri) = uri.parse("https://example.com" <> path)
  route.parse_route(uri)
}

pub fn parse_root_test() {
  parse("/") |> should.equal(Home)
}

pub fn parse_empty_path_test() {
  parse("") |> should.equal(Home)
}

pub fn parse_posts_index_test() {
  parse("/posts") |> should.equal(Posts(1))
}

pub fn parse_posts_page_2_test() {
  parse("/posts/page/2") |> should.equal(Posts(2))
}

pub fn parse_posts_page_invalid_test() {
  let result = parse("/posts/page/abc")
  case result {
    NotFound(_) -> Nil
    _ -> should.fail()
  }
}

pub fn parse_single_post_test() {
  parse("/posts/hello-arata") |> should.equal(Post("hello-arata"))
}

pub fn parse_projects_test() {
  parse("/projects") |> should.equal(Projects)
}

pub fn parse_project_detail_test() {
  parse("/projects/some-project") |> should.equal(Page("some-project"))
}

pub fn parse_links_test() {
  parse("/links") |> should.equal(Links)
}

pub fn parse_tags_index_test() {
  parse("/tags") |> should.equal(Tags)
}

pub fn parse_single_tag_test() {
  parse("/tags/gleam") |> should.equal(Tag("gleam"))
}

pub fn parse_standalone_page_test() {
  parse("/about") |> should.equal(Page("about"))
}

pub fn parse_unknown_path_test() {
  let result = parse("/unknown/deep/path")
  case result {
    NotFound(_) -> Nil
    _ -> should.fail()
  }
}

// Fix 10: static files must NOT be routed as pages. The SPA's router treats
// `/atom.xml`, `/rss.xml`, and `/sitemap.xml` as `NotFound` so modem lets the
// browser fetch them directly (otherwise they'd be intercepted as 404s).

pub fn parse_atom_xml_not_page_test() {
  let result = parse("/atom.xml")
  case result {
    NotFound(_) -> Nil
    _ -> should.fail()
  }
}

pub fn parse_rss_xml_not_page_test() {
  let result = parse("/rss.xml")
  case result {
    NotFound(_) -> Nil
    _ -> should.fail()
  }
}

pub fn parse_sitemap_xml_not_page_test() {
  let result = parse("/sitemap.xml")
  case result {
    NotFound(_) -> Nil
    _ -> should.fail()
  }
}

// Fix 10: a deep link to a single post should parse to `Post(slug)`, not
// `NotFound` — this is the case that broke RSS-on-sub-pages before the
// `target="_blank"` fix landed.

pub fn parse_deep_link_test() {
  parse("/posts/markdown") |> should.equal(Post("markdown"))
}

// href_url -------------------------------------------------------------------

pub fn href_home_test() {
  route.href_url(Home) |> should.equal("/")
}

pub fn href_posts_page_1_test() {
  route.href_url(Posts(1)) |> should.equal("/posts")
}

pub fn href_posts_page_2_test() {
  route.href_url(Posts(2)) |> should.equal("/posts/page/2")
}

pub fn href_post_test() {
  route.href_url(Post("hello")) |> should.equal("/posts/hello")
}

pub fn href_projects_test() {
  route.href_url(Projects) |> should.equal("/projects")
}

pub fn href_links_test() {
  route.href_url(Links) |> should.equal("/links")
}

pub fn href_tags_test() {
  route.href_url(Tags) |> should.equal("/tags")
}

pub fn href_tag_test() {
  route.href_url(Tag("gleam")) |> should.equal("/tags/gleam")
}

pub fn href_page_test() {
  route.href_url(Page("about")) |> should.equal("/about")
}

// Round-trip: parse(href_url(route)) == route -------------------------------

pub fn roundtrip_home_test() {
  parse(route.href_url(Home)) |> should.equal(Home)
}

pub fn roundtrip_posts_page_1_test() {
  parse(route.href_url(Posts(1))) |> should.equal(Posts(1))
}

pub fn roundtrip_posts_page_3_test() {
  parse(route.href_url(Posts(3))) |> should.equal(Posts(3))
}

pub fn roundtrip_post_test() {
  parse(route.href_url(Post("hello-arata")))
  |> should.equal(Post("hello-arata"))
}

pub fn roundtrip_tag_test() {
  parse(route.href_url(Tag("gleam"))) |> should.equal(Tag("gleam"))
}

pub fn roundtrip_page_test() {
  parse(route.href_url(Page("about"))) |> should.equal(Page("about"))
}
