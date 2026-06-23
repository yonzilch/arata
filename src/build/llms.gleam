import data/link.{type Link}
import data/page.{type Page}
import data/post.{type Post}
import data/project.{type Project}
import data/site.{type SiteMeta}
import gleam/list
import gleam/string

pub fn render(
  site_meta: SiteMeta,
  posts: List(Post),
  projects: List(Project),
  links: List(Link),
  pages: List(Page),
) -> String {
  let base_url = normalize_base_url(site_meta.base_url)

  let published_posts =
    list.filter(posts, fn(post) {
      case post.draft {
        True -> False
        False -> True
      }
    })

  "# "
  <> inline_text(site_meta.title)
  <> "\n\n"
  <> "> "
  <> inline_text(site_meta.description)
  <> "\n\n"
  <> "This file is a curated Markdown map of the site for large language models. "
  <> "Use the links below as canonical entry points for understanding the site, "
  <> "its posts, projects, pages, and related resources.\n\n"
  <> section("Core", [
    item(base_url, "Home", "/", "Homepage and primary site entry point."),
    item(base_url, "Posts", "/posts", "Blog post index."),
    item(base_url, "Projects", "/projects", "Project showcase index."),
    item(base_url, "Links", "/links", "Friend links and external resources."),
    item(base_url, "Tags", "/tags", "Tag index."),
    item(
      base_url,
      "Sitemap",
      "/sitemap.xml",
      "XML sitemap for crawlable pages.",
    ),
  ])
  <> section(
    "Posts",
    list.map(published_posts, fn(post) {
      item(base_url, post.title, "/posts/" <> post.slug, post.description)
    }),
  )
  <> section(
    "Pages",
    list.map(pages, fn(page) {
      item(base_url, page.title, "/" <> page.slug, "Standalone page.")
    }),
  )
  <> section(
    "Projects",
    list.map(projects, fn(project) {
      item(
        base_url,
        project.title,
        "/projects/" <> project.slug,
        project.description,
      )
    }),
  )
  <> section(
    "External Links",
    list.map(links, fn(link) {
      external_item(link.title, link.url, "External link.")
    }),
  )
}

fn section(title: String, lines: List(String)) -> String {
  case lines {
    [] -> ""
    _ -> "## " <> title <> "\n\n" <> string.join(lines, "\n") <> "\n\n"
  }
}

fn item(
  base_url: String,
  label: String,
  path: String,
  description: String,
) -> String {
  "- ["
  <> markdown_label(label)
  <> "]("
  <> absolute_url(base_url, inline_text(path))
  <> ") "
  <> inline_text(description)
}

fn external_item(label: String, url: String, description: String) -> String {
  "- ["
  <> markdown_label(label)
  <> "]("
  <> inline_text(url)
  <> ") "
  <> inline_text(description)
}

fn absolute_url(base_url: String, path: String) -> String {
  case base_url {
    "" -> path
    _ -> base_url <> path
  }
}

fn normalize_base_url(base_url: String) -> String {
  base_url
  |> string.trim
  |> trim_trailing_slashes
}

fn trim_trailing_slashes(value: String) -> String {
  case string.ends_with(value, "/") {
    True -> {
      let size = string.length(value)
      value
      |> string.slice(0, size - 1)
      |> trim_trailing_slashes
    }
    False -> value
  }
}

fn markdown_label(label: String) -> String {
  label
  |> inline_text
  |> string.split("[")
  |> string.join("\\[")
  |> string.split("]")
  |> string.join("\\]")
}

fn inline_text(value: String) -> String {
  value
  |> string.split("\r\n")
  |> string.join("\n")
  |> string.split("\r")
  |> string.join("\n")
  |> string.split("\n")
  |> string.join(" ")
  |> string.trim
}
