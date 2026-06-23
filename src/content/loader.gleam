//// Content loader: reads `.md` files from `content/posts/` and `content/pages/`
//// at build time, parses TOML frontmatter, and renders the markdown body via
//// mork. The result is serialized to `content_index.json` by the build
//// pipeline. The SPA fetches this JSON at startup instead of reading files
//// directly (which would require `simplifile` — a Node-only dependency that
//// breaks browser builds).
////
//// This module is **build-time only**. It must NOT be imported by the SPA
//// entry chain (`arata.gleam`). The SPA uses `content/runtime.gleam` instead,
//// which fetches the pre-built JSON.

import data/link.{type Link, Link}
import data/markdown
import data/page.{type Page, Page}
import data/post.{type Post, type TocEntry, Post, TocEntry}
import data/project.{type Project, Project}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import simplifile
import tom

/// Load all posts from `content/posts/`. Each `.md` file becomes a `Post`.
/// Posts are sorted by date descending (newest first).
pub fn load_posts() -> List(Post) {
  let dir = "content/posts"
  case simplifile.read_directory(at: dir) {
    Ok(filenames) ->
      filenames
      |> list.filter(fn(name) { string.ends_with(name, ".md") })
      |> list.map(fn(name) { load_post(dir <> "/" <> name, name) })
      |> list.filter_map(fn(r) { r })
      |> list.sort(by: fn(a, b) { string.compare(b.date, a.date) })
    Error(_) -> []
  }
}

/// Load all pages from `content/pages/`. Each `.md` file becomes a `Page`.
pub fn load_pages() -> List(Page) {
  let dir = "content/pages"
  case simplifile.read_directory(at: dir) {
    Ok(filenames) ->
      filenames
      |> list.filter(fn(name) { string.ends_with(name, ".md") })
      |> list.map(fn(name) { load_page(dir <> "/" <> name, name) })
      |> list.filter_map(fn(r) { r })
    Error(_) -> []
  }
}

/// Load the homepage from `content/pages/home.md`.
pub fn load_homepage() -> Page {
  let path = "content/pages/home.md"
  case load_page(path, "home.md") {
    Ok(page) -> page
    Error(_) -> Page(slug: "home", title: "arata", body: "", subtitle: None)
  }
}

/// Load all friend links from `content/links/*.md`.
///
/// Links have no markdown body — just frontmatter (`title`, `url`,
/// `description`). The list is sorted alphabetically by title for a stable
/// display order regardless of filesystem listing order.
pub fn load_links() -> List(Link) {
  let dir = "content/links"
  case simplifile.read_directory(at: dir) {
    Ok(filenames) ->
      filenames
      |> list.filter(fn(name) { string.ends_with(name, ".md") })
      |> list.map(fn(name) { load_link(dir <> "/" <> name) })
      |> list.filter_map(fn(r) { r })
      |> list.sort(by: fn(a, b) { string.compare(a.title, b.title) })
    Error(_) -> []
  }
}

fn load_link(path: String) -> Result(Link, Nil) {
  use content <- result.try(
    simplifile.read(from: path) |> result.replace_error(Nil),
  )
  let #(frontmatter, _body) = split_frontmatter(content)
  use toml <- result.try(tom.parse(frontmatter) |> result.replace_error(Nil))
  let title = tom.get_string(toml, ["title"]) |> result.unwrap("")
  let url = tom.get_string(toml, ["url"]) |> result.unwrap("")
  let description = tom.get_string(toml, ["description"]) |> result.unwrap("")
  let image = case tom.get_string(toml, ["image"]) {
    Ok(s) -> Some(s)
    Error(_) -> None
  }
  Ok(Link(title: title, url: url, description: description, image: image))
}

/// Load all projects from `content/projects/*.md`.
///
/// Projects have no markdown body — just frontmatter (`title`, `description`,
/// optional `link_to`/`image`/`github`/`demo`, and a `tags` array). The list
/// is sorted alphabetically by slug for a stable display order.
pub fn load_projects() -> List(Project) {
  let dir = "content/projects"
  case simplifile.read_directory(at: dir) {
    Ok(filenames) ->
      filenames
      |> list.filter(fn(name) { string.ends_with(name, ".md") })
      |> list.map(fn(name) { load_project(dir <> "/" <> name, name) })
      |> list.filter_map(fn(r) { r })
      |> list.sort(by: fn(a, b) { string.compare(a.slug, b.slug) })
    Error(_) -> []
  }
}

fn load_project(path: String, filename: String) -> Result(Project, Nil) {
  use content <- result.try(
    simplifile.read(from: path) |> result.replace_error(Nil),
  )
  let #(frontmatter, _body) = split_frontmatter(content)
  use toml <- result.try(tom.parse(frontmatter) |> result.replace_error(Nil))
  let slug = string.replace(filename, ".md", "")
  let title = tom.get_string(toml, ["title"]) |> result.unwrap(slug)
  let description = tom.get_string(toml, ["description"]) |> result.unwrap("")
  let link_to = case tom.get_string(toml, ["link_to"]) {
    Ok(s) -> Some(s)
    Error(_) -> None
  }
  let image = case tom.get_string(toml, ["image"]) {
    Ok(s) -> Some(s)
    Error(_) -> None
  }
  let github = case tom.get_string(toml, ["github"]) {
    Ok(s) -> Some(s)
    Error(_) -> None
  }
  let demo = case tom.get_string(toml, ["demo"]) {
    Ok(s) -> Some(s)
    Error(_) -> None
  }
  let tags = case tom.get_array(toml, ["tags"]) {
    Ok(arr) ->
      arr
      |> list.map(fn(item) {
        case tom.as_string(item) {
          Ok(s) -> s
          Error(_) -> ""
        }
      })
      |> list.filter(fn(s) { s != "" })
    Error(_) -> []
  }
  Ok(Project(
    slug: slug,
    title: title,
    description: description,
    link_to: link_to,
    image: image,
    github: github,
    demo: demo,
    tags: tags,
  ))
}

/// Load a single post from a file path.
fn load_post(path: String, filename: String) -> Result(Post, Nil) {
  use content <- result.try(
    simplifile.read(from: path) |> result.replace_error(Nil),
  )
  let #(frontmatter, body) = split_frontmatter(content)
  use toml <- result.try(tom.parse(frontmatter) |> result.replace_error(Nil))

  let slug = string.replace(filename, ".md", "")
  let title = tom.get_string(toml, ["title"]) |> result.unwrap(slug)
  let date = tom.get_string(toml, ["date"]) |> result.unwrap("")
  let updated = case tom.get_string(toml, ["updated"]) {
    Ok(d) -> Some(d)
    Error(_) -> None
  }
  let description = tom.get_string(toml, ["description"]) |> result.unwrap("")
  let tags = case tom.get_array(toml, ["tags"]) {
    Ok(arr) ->
      arr
      |> list.map(fn(item) {
        case tom.as_string(item) {
          Ok(s) -> s
          Error(_) -> ""
        }
      })
      |> list.filter(fn(s) { s != "" })
    Error(_) -> []
  }
  let draft = case tom.get_bool(toml, ["draft"]) {
    Ok(b) -> b
    Error(_) -> False
  }
  let tldr = case tom.get_string(toml, ["tldr"]) {
    Ok(t) -> Some(t)
    Error(_) -> None
  }
  let html_body = markdown.to_html(body) |> add_heading_ids
  let toc = extract_toc(body)
  let word_count = count_words(body)
  let reading_time = case word_count {
    0 -> 0
    n -> int.max(1, n / 200)
  }

  Ok(Post(
    slug: slug,
    title: title,
    date: date,
    updated: updated,
    description: description,
    body: html_body,
    toc: toc,
    tags: tags,
    draft: draft,
    tldr: tldr,
    word_count: word_count,
    reading_time: reading_time,
  ))
}

/// Load a single page from a file path.
fn load_page(path: String, filename: String) -> Result(Page, Nil) {
  use content <- result.try(
    simplifile.read(from: path) |> result.replace_error(Nil),
  )
  let #(frontmatter, body) = split_frontmatter(content)
  use toml <- result.try(tom.parse(frontmatter) |> result.replace_error(Nil))

  let slug = string.replace(filename, ".md", "")
  let title = tom.get_string(toml, ["title"]) |> result.unwrap(slug)
  let subtitle = case tom.get_string(toml, ["subtitle"]) {
    Ok(s) -> Some(s)
    Error(_) -> None
  }
  let html_body = markdown.to_html(body)

  Ok(Page(slug: slug, title: title, body: html_body, subtitle: subtitle))
}

/// Split a markdown file into frontmatter and body.
fn split_frontmatter(content: String) -> #(String, String) {
  case string.split_once(content, "+++\n") {
    Error(_) -> #("", content)
    Ok(#(_, rest)) ->
      case string.split_once(rest, "+++\n") {
        Error(_) -> #("", content)
        Ok(#(frontmatter, body)) -> #(frontmatter, body)
      }
  }
}

/// Extract a simple table of contents from the markdown body.
fn extract_toc(markdown: String) -> List(TocEntry) {
  markdown
  |> string.split("\n")
  |> list.filter(fn(line) { string.starts_with(line, "## ") })
  |> list.map(fn(line) {
    let title =
      line
      |> string.drop_start(up_to: 3)
      |> string.trim()
    let id = slugify(title)
    TocEntry(id: id, title: title, children: [])
  })
}

/// Convert a heading title to a URL-safe slug. Matches the algorithm used by
/// `add_heading_ids` so the TOC entry's `id` is identical to the `id`
/// attribute mork's HTML output is post-processed to carry: lowercase the
/// text, convert spaces/dashes/underscores to `-`, and drop common punctuation
/// (`. , : ? ! ( ) ' "`). Every other grapheme — including CJK characters,
/// letters, and numbers — is kept verbatim. Modern browsers resolve URL
/// fragments containing CJK characters fine, so headings like `## 简介` or
/// `## 導入` produce non-empty slugs (`简介`, `導入`) that the TOC's `#id`
/// anchors can resolve. This mirrors the algorithm used by `add_heading_ids`
/// so the TOC entry's `id` is identical to the `id` attribute mork's HTML
/// output is post-processed to carry.
fn slugify(text: String) -> String {
  text
  |> string.lowercase()
  |> string.to_graphemes()
  |> list.fold("", fn(acc, ch) {
    case ch {
      " " | "-" | "_" -> acc <> "-"
      "." | "," | ":" | "?" | "!" | "(" | ")" | "'" | "\"" -> acc
      _ -> acc <> ch
    }
  })
}

/// Strip HTML tags from a fragment of HTML by dropping everything between
/// `<` and `>` (inclusive). Used by `add_heading_ids` to extract plain text
/// from heading content that mork may have wrapped in inline tags like
/// `<code>` or `<a>`. HTML entities (e.g. `&lt;`) are left untouched.
fn strip_html_tags(html: String) -> String {
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

/// Post-process mork's HTML output to inject `id` attributes on `<h1>`–`<h6>`
/// heading tags. mork only emits `id`s when its `heading_ids` option is
/// enabled (and arata leaves it off), so we add them ourselves at load time.
/// The id is the slugified plain-text content of the heading (after stripping
/// any nested inline tags), matching `extract_toc`'s slugify so the TOC's
/// `#id` anchors resolve to the right heading.
///
/// The parser is intentionally simple: it splits the HTML on `<h`, then for
/// each piece starting with `1>`–`6>` (i.e. an `<hN>` opening tag with no
/// attributes — mork's default output), it extracts the heading text up to
/// the matching `</h`, slugifies the stripped text, and rebuilds the tag as
/// `<hN id="slug">…</hN>`. Pieces that don't start with a heading level
/// (e.g. `<header>`, `<hr />`) are left untouched.
fn add_heading_ids(html: String) -> String {
  let pieces = string.split(html, "<h")
  case pieces {
    [] -> html
    [first, ..rest] -> {
      let processed = list.map(rest, add_id_to_heading_piece)
      string.join([first, ..processed], "<h")
    }
  }
}

/// Process one piece produced by splitting HTML on `<h`. A heading piece
/// looks like `2>Title</h2>\n…`; a non-heading piece (e.g. from `<header>`)
/// looks like `eader>…</header>…`. We only rewrite the former.
fn add_id_to_heading_piece(piece: String) -> String {
  let levels = ["1>", "2>", "3>", "4>", "5>", "6>"]
  let is_heading = list.any(levels, fn(lv) { string.starts_with(piece, lv) })
  case is_heading {
    False -> piece
    True ->
      case string.split_once(piece, ">") {
        Ok(#(opening, rest)) ->
          case string.split_once(rest, "</h") {
            Ok(#(title, after_close)) -> {
              let slug = title |> strip_html_tags |> slugify
              opening
              <> " id=\""
              <> slug
              <> "\">"
              <> title
              <> "</h"
              <> after_close
            }
            Error(_) -> piece
          }
        Error(_) -> piece
      }
  }
}

/// Count words in a markdown string (rough estimate).
fn count_words(markdown: String) -> Int {
  markdown
  |> string.split("\n")
  |> list.filter(fn(line) { !string.starts_with(line, "```") })
  |> string.join("\n")
  |> string.split(" ")
  |> list.length()
}
