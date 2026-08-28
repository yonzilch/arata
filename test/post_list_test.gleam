//// Tests for the post list item rendering: the DRAFT badge and the PINNED
//// badge shown after the title. Pinned posts previously expressed themselves
//// only through sort position, which is indistinguishable from "newest post";
//// the badge makes the pinned state visible in the listing.

import data/post.{type Post, Post}
import gleam/option
import gleam/string
import gleeunit
import gleeunit/should
import lustre/element

import view/post_list

pub fn main() -> Nil {
  gleeunit.main()
}

// Fixtures ---------------------------------------------------------------------

fn sample_post(draft draft: Bool, pinned pinned: Bool) -> Post {
  Post(
    slug: "sample",
    title: "Sample Post",
    date: "2026-01-01",
    updated: option.None,
    description: "A sample post",
    body: "",
    toc: [],
    tags: [],
    draft: draft,
    pinned: pinned,
    tldr: option.None,
    word_count: 0,
    reading_time: 0,
  )
}

fn render(post: Post) -> String {
  post_list.view_items([post]) |> element.to_string
}

// Pinned badge -------------------------------------------------------------------

pub fn pinned_post_renders_pinned_badge_test() {
  let rendered = render(sample_post(draft: False, pinned: True))

  rendered
  |> string.contains("pinned-label")
  |> should.equal(True)

  rendered
  |> string.contains(">PINNED</span>")
  |> should.equal(True)
}

pub fn pinned_badge_carries_aria_label_test() {
  let rendered = render(sample_post(draft: False, pinned: True))

  rendered
  |> string.contains("aria-label=\"PINNED\"")
  |> should.equal(True)

  rendered
  |> string.contains("title=\"PINNED\"")
  |> should.equal(True)
}

pub fn non_pinned_post_renders_no_pinned_badge_test() {
  let rendered = render(sample_post(draft: False, pinned: False))

  rendered
  |> string.contains("pinned-label")
  |> should.equal(False)
}

pub fn non_pinned_post_renders_no_empty_badge_test() {
  // No stray empty marker spans either: the title link should carry only the
  // title text.
  let rendered = render(sample_post(draft: False, pinned: False))

  rendered
  |> string.contains("Sample Post</span></a>")
  |> should.equal(True)
}

// Draft badge (unchanged behaviour) ----------------------------------------------

pub fn draft_post_still_renders_draft_badge_test() {
  let rendered = render(sample_post(draft: True, pinned: False))

  rendered
  |> string.contains("draft-label")
  |> should.equal(True)

  rendered
  |> string.contains("pinned-label")
  |> should.equal(False)
}

pub fn draft_and_pinned_post_renders_both_badges_test() {
  let rendered = render(sample_post(draft: True, pinned: True))

  rendered
  |> string.contains("draft-label")
  |> should.equal(True)

  rendered
  |> string.contains("pinned-label")
  |> should.equal(True)
}
