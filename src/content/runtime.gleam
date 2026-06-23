//// Runtime content: the SPA's content source. Instead of reading `.md` files
//// at runtime (which requires `simplifile` — a Node-only dependency that
//// breaks browser builds), the SPA fetches a pre-built `content_index.json`
//// that the build pipeline generates from the `.md` files.
////
//// This module is browser-safe: it uses `rsvp` (HTTP fetch) to load the JSON
//// at startup. If the fetch fails (e.g. during development without a build
//// step), it falls back to empty content.

import data/link.{type Link, Link}
import data/page.{type Page, Page}
import data/post.{type Post, type TocEntry, Post, TocEntry}
import data/project.{type Project, Project}
import gleam/dynamic/decode
import gleam/option
import lustre/effect.{type Effect}
import rsvp

/// All content loaded from `content_index.json`.
pub type Content {
  Content(
    posts: List(Post),
    pages: List(Page),
    homepage: Page,
    links: List(Link),
    projects: List(Project),
  )
}

/// Messages produced by the content loading effect.
pub type ContentMsg {
  ContentLoaded(result: Result(Content, rsvp.Error(String)))
}

/// Fetch `content_index.json` and decode it. Dispatches `ContentLoaded`
/// with the result.
pub fn load() -> Effect(ContentMsg) {
  let handler =
    rsvp.expect_json(decode_content_index(), fn(result) {
      ContentLoaded(result)
    })
  rsvp.get("/content_index.json", handler)
}

/// A decoder for `content_index.json`.
fn decode_content_index() -> decode.Decoder(Content) {
  use posts <- decode.field("posts", decode.list(decode_post()))
  use pages <- decode.field("pages", decode.list(decode_page()))
  use homepage <- decode.field("homepage", decode_page())
  use links <- decode.field("links", decode.list(decode_link()))
  use projects <- decode.field("projects", decode.list(decode_project()))
  decode.success(Content(posts:, pages:, homepage:, links:, projects:))
}

fn decode_post() -> decode.Decoder(Post) {
  use slug <- decode.field("slug", decode.string)
  use title <- decode.field("title", decode.string)
  use date <- decode.field("date", decode.string)
  use updated <- decode.optional_field(
    "updated",
    option.None,
    decode.optional(decode.string),
  )
  use description <- decode.field("description", decode.string)
  use body <- decode.field("body", decode.string)
  use toc <- decode.field("toc", decode.list(decode_toc_entry()))
  use tags <- decode.field("tags", decode.list(decode.string))
  use draft <- decode.optional_field("draft", False, decode.bool)
  use tldr <- decode.optional_field(
    "tldr",
    option.None,
    decode.optional(decode.string),
  )
  use word_count <- decode.field("word_count", decode.int)
  use reading_time <- decode.field("reading_time", decode.int)
  decode.success(Post(
    slug: slug,
    title: title,
    date: date,
    updated: updated,
    description: description,
    body: body,
    toc: toc,
    tags: tags,
    draft: draft,
    tldr: tldr,
    word_count: word_count,
    reading_time: reading_time,
  ))
}

fn decode_page() -> decode.Decoder(Page) {
  use slug <- decode.field("slug", decode.string)
  use title <- decode.field("title", decode.string)
  use body <- decode.field("body", decode.string)
  use subtitle <- decode.optional_field(
    "subtitle",
    option.None,
    decode.optional(decode.string),
  )
  decode.success(Page(slug: slug, title: title, body: body, subtitle: subtitle))
}

fn decode_toc_entry() -> decode.Decoder(TocEntry) {
  use id <- decode.field("id", decode.string)
  use title <- decode.field("title", decode.string)
  use children <- decode.optional_field(
    "children",
    [],
    decode.list(decode_toc_entry()),
  )
  decode.success(TocEntry(id: id, title: title, children: children))
}

fn decode_link() -> decode.Decoder(Link) {
  use title <- decode.field("title", decode.string)
  use url <- decode.field("url", decode.string)
  use description <- decode.field("description", decode.string)
  use image <- decode.optional_field(
    "image",
    option.None,
    decode.optional(decode.string),
  )
  decode.success(Link(
    title: title,
    url: url,
    description: description,
    image: image,
  ))
}

fn decode_project() -> decode.Decoder(Project) {
  use slug <- decode.field("slug", decode.string)
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.string)
  use link_to <- decode.optional_field(
    "link_to",
    option.None,
    decode.optional(decode.string),
  )
  use image <- decode.optional_field(
    "image",
    option.None,
    decode.optional(decode.string),
  )
  use github <- decode.optional_field(
    "github",
    option.None,
    decode.optional(decode.string),
  )
  use gitlab <- decode.optional_field(
    "gitlab",
    option.None,
    decode.optional(decode.string),
  )
  use codeberg <- decode.optional_field(
    "codeberg",
    option.None,
    decode.optional(decode.string),
  )
  use forgejo <- decode.optional_field(
    "forgejo",
    option.None,
    decode.optional(decode.string),
  )
  use demo <- decode.optional_field(
    "demo",
    option.None,
    decode.optional(decode.string),
  )
  use tags <- decode.optional_field("tags", [], decode.list(decode.string))
  decode.success(Project(
    slug: slug,
    title: title,
    description: description,
    link_to: link_to,
    image: image,
    github: github,
    gitlab: gitlab,
    codeberg: codeberg,
    forgejo: forgejo,
    demo: demo,
    tags: tags,
  ))
}
