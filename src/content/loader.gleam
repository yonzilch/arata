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
/// preceding h3. Reading the `id` straight from the rendered HTML guarantees
/// the TOC's `#id` anchors resolve to the right heading — no risk of the
/// slugify algorithm drifting out of sync between TOC extraction and ID
/// injection. CJK headings, which slugify leaves untouched and which would
/// otherwise produce IDs that browsers can't match against percent-encoded
/// fragment links, fall back to sequential `heading-N` IDs (assigned by
/// `add_heading_ids`), and we just read those back here.
fn extract_toc_from_html(html: String) -> List(TocEntry) {
  let all_headings = parse_headings(html)
  let toc_headings =
    list.filter(all_headings, fn(entry) {
      let #(level, _, _) = entry
      level == 2 || level == 3 || level == 4
    })
  build_toc_tree(toc_headings)
}

/// Parse `<hN id="...">Title</hN>` tags out of rendered HTML. Returns a flat
/// list of `(level, id, title)` triples in document order. Non-heading pieces
/// produced by splitting on `<h` (e.g. `<hr />`'s `r />...`, `<header>`'s
/// `eader>...`) fail the level-digit or `id="` lookups and are dropped.
fn parse_headings(html: String) -> List(#(Int, String, String)) {
  html
  |> string.split("<h")
  |> list.filter_map(fn(piece) {
    use #(level_ch, rest) <- result.try(string.pop_grapheme(piece))
    use level <- result.try(int.parse(level_ch))
    use #(after_id_open, _) <- result.try(string.split_once(rest, "id=\""))
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
/// triples. Headings at the minimum level present become top-level entries;
/// each heading's children are the consecutive deeper-level headings that
/// follow it, up to the next heading at the same or shallower level.
fn build_toc_tree(headings: List(#(Int, String, String))) -> List(TocEntry) {
  case headings {
    [] -> []
    [first, ..] -> {
      let #(first_level, _, _) = first
      build_at_level(headings, first_level)
    }
  }
}

/// Process `headings` at `level`, returning a list of `TocEntry`. Each entry
/// at `level` consumes the following deeper-level headings as its children
/// (recursively built via `build_at_level` at the child's level), stopping at
/// the next heading at `level` or shallower.
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
    // A shallower heading ends this level (its parent will handle it);
    // a deeper heading with no preceding peer at this level is skipped.
    [#(lvl, _, _), ..] if lvl < level -> []
    [_, ..rest] -> build_at_level(rest, level)
  }
}

/// Split `headings` at the first entry whose level is `<= level`, returning
/// the deeper-level run (children) and the remainder (siblings). Used by
/// `build_at_level` to carve out a heading's subtree.
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

/// First pass of heading-id generation: lowercase the text, convert
/// spaces/dashes/underscores to `-`, and drop common punctuation
/// (`. , : ? ! ( ) ' "`). Every other grapheme — including CJK characters,
/// letters, and numbers — is kept verbatim. The result is then handed to
/// `needs_fallback_id`: if it's empty, all hyphens, or contains any non-ASCII
/// character (e.g. `## 简介` → `简介`), `add_heading_ids` discards it and
/// substitutes a sequential `heading-N` id instead. Bare CJK ids would
/// otherwise break TOC navigation — browsers percent-encode the `#fragment`
/// of a `#简介` link to `#%E7%AE%80%E4%BB%8B…`, which then fails to match an
/// `id="简介"` attribute — so we fall back to ASCII-only ids that always agree
/// between the `id` attribute and the TOC's `#id` anchor.
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
/// any nested inline tags). Headings whose slug is empty, all hyphens, or
/// contains non-ASCII characters (e.g. CJK titles like `## 简介`) get a
/// sequential fallback id `heading-1`, `heading-2`, … instead — see
/// `slugify` for why. `extract_toc_from_html` reads the ids back off the
/// rendered HTML, so TOC anchors always match.
///
/// The parser is intentionally simple: it splits the HTML on `<h`, then for
/// each piece starting with `1>`–`6>` (i.e. an `<hN>` opening tag with no
/// attributes — mork's default output), it extracts the heading text up to
/// the matching `</h`, slugifies the stripped text, and rebuilds the tag as
/// `<hN id="slug">…</hN>`. Pieces that don't start with a heading level
/// (e.g. `<header>`, `<hr />`) are left untouched. A running counter tracks
/// the next sequential fallback number; it only advances when a fallback id
/// is actually assigned.
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

/// Process one piece produced by splitting HTML on `<h`. A heading piece
/// looks like `2>Title</h2>\n…`; a non-heading piece (e.g. from `<header>`)
/// looks like `eader>…</header>…`. We only rewrite the former, returning
/// `#(rewritten_piece, next_counter)`. `next_counter` is the next sequential
/// fallback number to hand to the following heading — it advances by one only
/// when this heading needed a fallback id (`heading-{counter}`); otherwise it
/// stays put so the ASCII slugs don't burn numbers.
///
/// The heading's title text is also wrapped in an `<a href="#{final_id}">` so
/// clicking it scrolls to the heading's own anchor — matching the ToC links'
/// `#id` same-page-scroll behaviour.
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
/// True when the slug is empty, all hyphens, or contains any character outside
/// ASCII lowercase letters, digits, and hyphens (e.g. CJK graphemes, which
/// `slugify` leaves verbatim).
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

/// Whether a grapheme is an ASCII lowercase letter, digit, or hyphen — the
/// only characters a browser-safe URL fragment slug should contain.
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

/// Count words in a markdown string (rough estimate).
fn count_words(markdown: String) -> Int {
  markdown
  |> string.split("\n")
  |> list.filter(fn(line) { !string.starts_with(line, "```") })
  |> string.join("\n")
  |> string.split(" ")
  |> list.length()
}
