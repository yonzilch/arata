//// aratafetch: a neofetch-style homepage summary component.
////
//// This module is intentionally view-only plus small runtime aggregation
//// helpers. It does not fetch data and does not depend on config directly.
//// The caller decides whether the component is enabled and passes the loaded
//// content lists in after `content_index.json` is ready.
////
//// Invariants:
////   - draft posts are excluded from post count, word count, and tag count
////   - total words reuse `Post.word_count`; markdown is not reparsed
////   - tags are counted uniquely, case-insensitively
////   - comments and maintenance duration are optional because arata currently
////     has no reliable runtime comment-count source

import data/link.{type Link}
import data/post.{type Post}
import data/project.{type Project}
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html

pub type Stats {
  Stats(
    post_count: Int,
    word_count: Int,
    tag_count: Int,
    link_count: Int,
    project_count: Int,
    maintain_for: Option(String),
    site_title: String,
    description: String,
    base_url: String,
  )
}

/// Build aratafetch stats from already-loaded runtime content.
///
/// `maintain_for` is deliberately a display string instead of a date because
/// Gleam/JS date parsing would add complexity and timezone edge cases. The
/// caller can pass values like:
///
///   Some("since 2024-11-05")
///   Some("2 years")
///   None
///
pub fn from_content(
  links: List(Link),
  posts: List(Post),
  projects: List(Project),
  site_title: String,
  description: String,
  base_url: String,
  maintain_for: Option(String),
) -> Stats {
  let published_posts = list.filter(posts, fn(post) { !post.draft })

  Stats(
    link_count: list.length(links),
    post_count: list.length(published_posts),
    word_count: total_words(published_posts),
    project_count: list.length(projects),
    tag_count: unique_tag_count(published_posts),
    site_title: site_title,
    description: description,
    base_url: base_url,
    maintain_for: maintain_for,
  )
}

/// Render the aratafetch block.
///
/// When disabled, returns `none()` so the homepage is identical to the old
/// rendering path.
pub fn view(enabled: Bool, stats: Stats) -> Element(msg) {
  case enabled {
    False -> none()

    True ->
      html.section(
        [
          attribute.class("aratafetch"),
          attribute.attribute("aria-label", "Site summary"),
        ],
        [
          html.pre([attribute.class("aratafetch-pre")], [
            html.text(render(stats)),
          ]),
        ],
      )
  }
}

fn total_words(posts: List(Post)) -> Int {
  list.fold(posts, 0, fn(total, post) { total + post.word_count })
}

fn unique_tag_count(posts: List(Post)) -> Int {
  posts
  |> list.fold(dict.new(), fn(tags, post) {
    list.fold(post.tags, tags, fn(tags, tag) {
      dict.insert(tags, string.lowercase(tag), Nil)
    })
  })
  |> dict.to_list
  |> list.length
}

fn render(stats: Stats) -> String {
  string.join(
    list.flatten([
      [
        "[root@arata:~]$ aratafetch",
        "",
        "        /\\",
        "       /  \\",
        "      / /\\ \\",
        "     / ____ \\",
        "    /_/    \\_\\",
        "",
      ],
      optional_row("maintain", stats.maintain_for),
      positive_row("links", stats.link_count),
      positive_row("posts", stats.post_count),
      positive_row("words", stats.word_count),
      positive_row("projects", stats.project_count),
      positive_row("tags", stats.tag_count),
      text_row("site", stats.site_title),
      text_row("url", display_base_url(stats.base_url)),
      text_row("description", stats.description),
    ]),
    "\n",
  )
}

fn row(label: String, value: String) -> String {
  label <> repeat(" ", int.max(1, 12 - string.length(label))) <> value
}

fn text_row(label: String, value: String) -> List(String) {
  case string.trim(value) {
    "" -> []
    value -> [row(label, value)]
  }
}

fn positive_row(label: String, value: Int) -> List(String) {
  case value > 0 {
    True -> [row(label, int.to_string(value))]
    False -> []
  }
}

fn optional_row(label: String, value: Option(String)) -> List(String) {
  case value {
    Some(text) -> text_row(label, text)
    None -> []
  }
}

fn repeat(chunk: String, times: Int) -> String {
  case times <= 0 {
    True -> ""
    False -> chunk <> repeat(chunk, times - 1)
  }
}

fn display_base_url(url: String) -> String {
  url
  |> strip_url_scheme
  |> trim_trailing_slash
}

fn strip_url_scheme(url: String) -> String {
  case string.split_once(url, "://") {
    Ok(#(_scheme, rest)) -> rest
    Error(_) -> url
  }
}

fn trim_trailing_slash(url: String) -> String {
  case string.ends_with(url, "/") {
    True -> {
      let size = string.length(url)

      url
      |> string.slice(0, size - 1)
      |> trim_trailing_slash
    }

    False -> url
  }
}
