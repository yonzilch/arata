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
import gleam/order.{Eq}
import gleam/result
import gleam/string
import simplifile
import tom

const default_link_weight = 999

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
/// Ordering follows Zola's `weight` convention:
///
///   - lower `weight` appears earlier
///   - links without `weight` default to `999`
///   - equal weights fall back to title ordering for deterministic output
///
/// Supported frontmatter shapes:
///
///   - arata-native: `url`, `image`
///   - Zola-style: `[extra] link_to`, `[extra] remote_image`
pub fn load_links() -> List(Link) {
  let dir = "content/links"
  case simplifile.read_directory(at: dir) {
    Ok(filenames) ->
      filenames
      |> list.filter(fn(name) { string.ends_with(name, ".md") })
      |> list.map(fn(name) { load_link(dir <> "/" <> name) })
      |> list.filter_map(fn(r) { r })
      |> list.sort(by: compare_links)
    Error(_) -> []
  }
}

fn compare_links(a: Link, b: Link) -> order.Order {
  case int.compare(a.weight, b.weight) {
    Eq -> string.compare(string.lowercase(a.title), string.lowercase(b.title))
    ordering -> ordering
  }
}

fn load_link(path: String) -> Result(Link, Nil) {
  use content <- result.try(
    simplifile.read(from: path) |> result.replace_error(Nil),
  )
  let #(frontmatter, _body) = split_frontmatter(content)
  use toml <- result.try(tom.parse(frontmatter) |> result.replace_error(Nil))

  let title = tom.get_string(toml, ["title"]) |> result.unwrap("")
  let description = tom.get_string(toml, ["description"]) |> result.unwrap("")

  let url =
    tom.get_string(toml, ["url"])
    |> result.or(tom.get_string(toml, ["extra", "link_to"]))
    |> result.unwrap("")

  let image =
    tom.get_string(toml, ["image"])
    |> result.or(tom.get_string(toml, ["extra", "remote_image"]))
    |> result.map(Some)
    |> result.unwrap(None)

  let weight =
    tom.get_int(toml, ["weight"])
    |> result.unwrap(default_link_weight)

  Ok(Link(
    title: title,
    url: url,
    description: description,
    image: image,
    weight: weight,
  ))
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
  let gitlab = case tom.get_string(toml, ["gitlab"]) {
    Ok(s) -> Some(s)
    Error(_) -> None
  }
  let codeberg = case tom.get_string(toml, ["codeberg"]) {
    Ok(s) -> Some(s)
    Error(_) -> None
  }
  let forgejo = case tom.get_string(toml, ["forgejo"]) {
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
    gitlab: gitlab,
    codeberg: codeberg,
    forgejo: forgejo,
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
  let pinned = case tom.get_bool(toml, ["pinned"]) {
    Ok(b) -> b
    Error(_) -> False
  }
  let tldr = case tom.get_string(toml, ["tldr"]) {
    Ok(t) -> Some(t)
    Error(_) -> None
  }
  let html_body = markdown.to_html(body) |> add_heading_ids
  let toc = extract_toc_from_html(html_body)
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
    pinned: pinned,
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

/// Extract a table of contents from rendered HTML. Parses every `<hN id="...">`
/// heading tag (N = 2, 3, 4) mork emitted and `add_heading_ids` stamped with an
/// `id`, then builds a nested `TocEntry` tree: h2 entries sit at the top level,
/// h3 entries nest under the preceding h2, and h4 entries nest under the
/// preceding h3.
fn extract_toc_from_html(html: String) -> List(TocEntry) {
  let all_headings = parse_headings(html)
  let toc_headings =
    list.filter(all_headings, fn(entry) {
      let #(level, _, _) = entry
      level == 2 || level == 3 || level == 4
    })
  build_toc_tree(toc_headings)
}

/// Parse `<hN id="...">Title</hN>` tags out of rendered HTML.
fn parse_headings(html: String) -> List(#(Int, String, String)) {
  html
  |> string.split("<h")
  |> list.filter_map(fn(piece) {
    use #(level_ch, rest) <- result.try(string.pop_grapheme(piece))
    use level <- result.try(int.parse(level_ch))
    use #(_, after_id_open) <- result.try(string.split_once(rest, "id=\""))
    use #(id, after_id_close) <- result.try(string.split_once(
      after_id_open,
      "\"",
    ))
    use #(_, title_with_rest) <- result.try(string.split_once(
      after_id_close,
      ">",
    ))
    use #(title, _) <- result.try(string.split_once(title_with_rest, "</h"))
    let clean_title = title |> strip_html_tags
    Ok(#(level, id, clean_title))
  })
}

/// Build a nested `TocEntry` tree from a flat list of `(level, id, title)`
/// triples.
fn build_toc_tree(headings: List(#(Int, String, String))) -> List(TocEntry) {
  case headings {
    [] -> []
    [first, ..] -> {
      let #(first_level, _, _) = first
      build_at_level(headings, first_level)
    }
  }
}

/// Process `headings` at `level`, returning a list of `TocEntry`.
fn build_at_level(
  headings: List(#(Int, String, String)),
  level: Int,
) -> List(TocEntry) {
  case headings {
    [] -> []
    [#(lvl, id, title), ..rest] if lvl == level -> {
      let #(children_headings, siblings) = take_until_at_or_below(rest, level)
      let children = case children_headings {
        [] -> []
        [#(child_level, _, _), ..] ->
          build_at_level(children_headings, child_level)
      }
      let entry = TocEntry(id: id, title: title, children: children)
      [entry, ..build_at_level(siblings, level)]
    }
    [#(lvl, _, _), ..] if lvl < level -> []
    [_, ..rest] -> build_at_level(rest, level)
  }
}

/// Split `headings` at the first entry whose level is `<= level`.
fn take_until_at_or_below(
  headings: List(#(Int, String, String)),
  level: Int,
) -> #(List(#(Int, String, String)), List(#(Int, String, String))) {
  case headings {
    [] -> #([], [])
    [#(lvl, _, _), ..] if lvl <= level -> #([], headings)
    [h, ..rest] -> {
      let #(children, siblings) = take_until_at_or_below(rest, level)
      #([h, ..children], siblings)
    }
  }
}

/// First pass of heading-id generation.
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

/// Strip HTML tags from a fragment of HTML.
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

/// Post-process mork's HTML output to inject `id` attributes on `<h1>`–`<h6>`.
fn add_heading_ids(html: String) -> String {
  let pieces = string.split(html, "<h")
  case pieces {
    [] -> html
    [first, ..rest] -> {
      let #(processed, _next_counter) =
        list.fold(rest, #([], 1), fn(acc, piece) {
          let #(acc_list, counter) = acc
          let #(new_piece, next_counter) =
            add_id_to_heading_piece(piece, counter)
          #([new_piece, ..acc_list], next_counter)
        })
      string.join([first, ..list.reverse(processed)], "<h")
    }
  }
}

/// Process one piece produced by splitting HTML on `<h`.
fn add_id_to_heading_piece(piece: String, counter: Int) -> #(String, Int) {
  let levels = ["1>", "2>", "3>", "4>", "5>", "6>"]
  let is_heading = list.any(levels, fn(lv) { string.starts_with(piece, lv) })
  case is_heading {
    False -> #(piece, counter)
    True ->
      case string.split_once(piece, ">") {
        Ok(#(opening, rest)) ->
          case string.split_once(rest, "</h") {
            Ok(#(title, after_close)) -> {
              let slug = title |> strip_html_tags |> slugify
              let #(final_id, next_counter) = case needs_fallback_id(slug) {
                True -> #("heading-" <> int.to_string(counter), counter + 1)
                False -> #(slug, counter)
              }
              #(
                opening
                  <> " id=\""
                  <> final_id
                  <> "\"><a href=\"#"
                  <> final_id
                  <> "\">"
                  <> title
                  <> "</a></h"
                  <> after_close,
                next_counter,
              )
            }
            Error(_) -> #(piece, counter)
          }
        Error(_) -> #(piece, counter)
      }
  }
}

/// Whether a slugified heading needs the sequential `heading-N` fallback.
fn needs_fallback_id(slug: String) -> Bool {
  case slug {
    "" -> True
    _ -> {
      let graphemes = string.to_graphemes(slug)
      let has_non_ascii =
        list.any(graphemes, fn(ch) { !is_ascii_slug_char(ch) })
      let all_hyphens = list.all(graphemes, fn(ch) { ch == "-" })
      has_non_ascii || all_hyphens
    }
  }
}

/// Whether a grapheme is an ASCII lowercase letter, digit, or hyphen.
fn is_ascii_slug_char(ch: String) -> Bool {
  case ch {
    "a"
    | "b"
    | "c"
    | "d"
    | "e"
    | "f"
    | "g"
    | "h"
    | "i"
    | "j"
    | "k"
    | "l"
    | "m"
    | "n"
    | "o"
    | "p"
    | "q"
    | "r"
    | "s"
    | "t"
    | "u"
    | "v"
    | "w"
    | "x"
    | "y"
    | "z"
    | "0"
    | "1"
    | "2"
    | "3"
    | "4"
    | "5"
    | "6"
    | "7"
    | "8"
    | "9"
    | "-" -> True
    _ -> False
  }
}

/// Count words in a markdown string.
fn count_words(markdown: String) -> Int {
  let text =
    markdown
    |> string.split("\n")
    |> list.filter(fn(line) { !string.starts_with(line, "```") })
    |> string.join(" ")
  let graphemes = string.to_graphemes(text)
  let #(count, _in_word) =
    list.fold(graphemes, #(0, False), fn(acc, ch) {
      let #(count, in_word) = acc
      case ch {
        " " | "\n" | "\t" -> #(count, False)
        _ ->
          case string.byte_size(ch) > 1 {
            True -> #(count + 1, False)
            False ->
              case in_word {
                True -> #(count, True)
                False -> #(count + 1, True)
              }
          }
      }
    })
  count
}
