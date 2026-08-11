//// Tests for the tag index and search data modules.

import data/post.{type Post, Post, find_tag, order_posts, tag_index}
import data/search
import gleam/list
import gleam/option.{None}
import gleeunit
import gleeunit/should

pub fn main() -> Nil {
  gleeunit.main()
}

// Tag index ------------------------------------------------------------------

fn sample_posts() -> List(Post) {
  [
    Post(
      slug: "a",
      title: "Post A",
      date: "2026-01-01",
      updated: None,
      description: "About gleam",
      body: "",
      toc: [],
      tags: ["gleam", "lustre"],
      draft: False,
      pinned: False,
      tldr: None,
      word_count: 0,
      reading_time: 0,
    ),
    Post(
      slug: "b",
      title: "Post B",
      date: "2026-01-02",
      updated: None,
      description: "About css",
      body: "",
      toc: [],
      tags: ["css", "design"],
      draft: False,
      pinned: False,
      tldr: None,
      word_count: 0,
      reading_time: 0,
    ),
    Post(
      slug: "c",
      title: "Post C",
      date: "2026-01-03",
      updated: None,
      description: "More gleam",
      body: "",
      toc: [],
      tags: ["gleam"],
      draft: False,
      pinned: False,
      tldr: None,
      word_count: 0,
      reading_time: 0,
    ),
  ]
}

pub fn tag_index_builds_test() {
  let entries = tag_index(sample_posts())
  // Should have 4 unique tags: css, design, gleam, lustre
  list.length(entries) |> should.equal(4)
}

pub fn tag_index_sorted_by_name_test() {
  let entries = tag_index(sample_posts())
  let names = list.map(entries, fn(e) { e.name })
  // Sorted alphabetically: css, design, gleam, lustre
  names |> should.equal(["css", "design", "gleam", "lustre"])
}

pub fn tag_index_gleam_has_2_posts_test() {
  let entries = tag_index(sample_posts())
  let assert Ok(gleam_entry) = find_tag(entries, "gleam")
  list.length(gleam_entry.posts) |> should.equal(2)
}

pub fn tag_index_css_has_1_post_test() {
  let entries = tag_index(sample_posts())
  let assert Ok(css_entry) = find_tag(entries, "css")
  list.length(css_entry.posts) |> should.equal(1)
}

pub fn tag_index_find_missing_returns_error_test() {
  let entries = tag_index(sample_posts())
  find_tag(entries, "nonexistent") |> should.be_error()
}

// Search ---------------------------------------------------------------------

pub fn search_empty_query_returns_empty_test() {
  let results = search.search(sample_posts(), "")
  list.length(results) |> should.equal(0)
}

pub fn search_matching_title_test() {
  let results = search.search(sample_posts(), "post a")
  list.length(results) |> should.equal(1)
}

pub fn search_matching_description_test() {
  let results = search.search(sample_posts(), "gleam")
  // "gleam" appears in description of Post A and Post C
  list.length(results) |> should.equal(2)
}

pub fn search_matching_tag_test() {
  let results = search.search(sample_posts(), "css")
  list.length(results) |> should.equal(1)
}

pub fn search_case_insensitive_test() {
  let results_lower = search.search(sample_posts(), "gleam")
  let results_upper = search.search(sample_posts(), "GLEAM")
  list.length(results_lower) |> should.equal(list.length(results_upper))
}

pub fn search_no_match_returns_empty_test() {
  let results = search.search(sample_posts(), "nonexistent")
  list.length(results) |> should.equal(0)
}

// Pinned ordering -------------------------------------------------------------

/// Build a minimal `Post` with the given slug, date, and pinned state, so
/// `order_posts` tests can focus on ordering without boilerplate.
fn post(slug: String, date: String, pinned: Bool) -> Post {
  Post(
    slug: slug,
    title: slug,
    date: date,
    updated: None,
    description: "",
    body: "",
    toc: [],
    tags: [],
    draft: False,
    pinned: pinned,
    tldr: None,
    word_count: 0,
    reading_time: 0,
  )
}

pub fn order_posts_pinned_before_regular_test() {
  // Given an already date-sorted list, a pinned post must move ahead of the
  // newest non-pinned post even when it is older.
  let posts = [
    post("newest", "2026-03-01", False),
    post("oldest-pinned", "2026-01-01", True),
  ]
  let slugs = list.map(order_posts(posts), fn(p) { p.slug })
  slugs |> should.equal(["oldest-pinned", "newest"])
}

pub fn order_posts_multiple_pinned_keep_date_order_test() {
  // Pinned posts group together and keep date-descending order among themselves.
  let posts = [
    post("pinned-old", "2026-01-01", True),
    post("regular", "2026-04-01", False),
    post("pinned-new", "2026-02-01", True),
  ]
  let slugs = list.map(order_posts(posts), fn(p) { p.slug })
  slugs |> should.equal(["pinned-new", "pinned-old", "regular"])
}

pub fn order_posts_regular_keep_date_order_test() {
  // Non-pinned posts retain the existing newest-first date ordering.
  let posts = [
    post("old", "2026-01-01", False),
    post("new", "2026-03-01", False),
    post("mid", "2026-02-01", False),
  ]
  let slugs = list.map(order_posts(posts), fn(p) { p.slug })
  slugs |> should.equal(["new", "mid", "old"])
}

pub fn order_posts_identical_dates_deterministic_test() {
  // Equal dates must not rely on sort stability; the slug tiebreak keeps the
  // result deterministic regardless of input order.
  let posts = [
    post("b", "2026-01-01", False),
    post("a", "2026-01-01", False),
  ]
  let slugs = list.map(order_posts(posts), fn(p) { p.slug })
  slugs |> should.equal(["a", "b"])
}

pub fn order_posts_all_regular_is_unchanged_test() {
  // A list with no pinned posts behaves exactly as it does today.
  let posts = [
    post("old", "2026-01-01", False),
    post("new", "2026-03-01", False),
  ]
  let slugs = list.map(order_posts(posts), fn(p) { p.slug })
  slugs |> should.equal(["new", "old"])
}
