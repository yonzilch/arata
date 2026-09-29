//// Static `<head>` metadata builder for the SPA shell.
////
//// Produces `<title>`, the description / OpenGraph `<meta>` set, and the
//// Fediverse `<meta>` tag, mirroring apollo's `partials/header.html` SEO
//// section.
////
//// This is a plain string builder rather than a Lustre view. The shell is
//// written straight to `dist/index.html` by `build/pipeline`, which needs a
//// `String`; Lustre's virtual DOM has no string renderer in this dependency
//// set, so an `Element(msg)` cannot be embedded here.
////
//// apollo deduplicates against `page.extra.meta` using the
//// `page_has_og_title` / `page_has_og_description` / `page_has_description`
//// flags. arata does the same: if the caller passes custom `meta` entries,
//// the auto-generated ones are suppressed when the keys match.

import data/site.{type SiteMeta}
import gleam/list
import gleam/option.{type Option}
import gleam/string

/// One custom `<meta>` entry from frontmatter (apollo's `page.extra.meta`).
/// Each becomes `<meta key="value">`.
pub type MetaEntry {
  MetaEntry(key: String, value: String)
}

/// Build the head metadata block: `<title>` plus every `<meta>` tag.
///
/// - `site`: the site-level metadata.
/// - `page_title`: the title of the current page, or `None` for the site root.
/// - `page_description`: the page description, or `None` for the site default.
/// - `page_path`: the deployment-prefixed URL path, used for `og:url`. For the
///   shell this is the base path with a trailing slash.
/// - `custom_meta`: user-supplied meta entries; these suppress the
///   auto-generated `og:title` / `og:description` / `description` on key match.
pub fn head_metadata(
  site: SiteMeta,
  page_title: Option(String),
  page_description: Option(String),
  page_path: String,
  custom_meta: List(MetaEntry),
) -> String {
  let title = option.unwrap(page_title, site.title)
  let description = option.unwrap(page_description, site.description)
  let url = site.base_url <> page_path

  let has_og_title = has_key(custom_meta, "og:title")
  let has_og_description = has_key(custom_meta, "og:description")
  let has_description = has_key(custom_meta, "description")

  let auto_desc = case has_description {
    False -> [MetaEntry("description", description)]
    True -> []
  }
  let auto_og_title = case has_og_title {
    False -> [MetaEntry("og:title", title)]
    True -> []
  }
  let auto_og_desc = case has_og_description {
    False -> [MetaEntry("og:description", description)]
    True -> []
  }
  let auto_meta =
    list.flatten([
      auto_desc,
      auto_og_title,
      auto_og_desc,
      [MetaEntry("og:url", url), MetaEntry("og:type", "website")],
    ])

  let all_meta = list.append(auto_meta, custom_meta)

  title_tag(title)
  <> meta_tags(all_meta)
  <> fediverse_meta(site.fediverse_creator)
}

/// Whether `custom_meta` already declares the given key.
fn has_key(entries: List(MetaEntry), key: String) -> Bool {
  list.any(entries, fn(entry) { entry.key == key })
}

/// The `<title>` element.
fn title_tag(title: String) -> String {
  "<title>" <> escape(title) <> "</title>"
}

/// Render each entry as a `<meta>` tag.
///
/// `og:*` keys use the `property` attribute, matching what social scrapers
/// expect; everything else uses `name`.
fn meta_tags(entries: List(MetaEntry)) -> String {
  entries
  |> list.map(render_meta)
  |> string.concat
}

fn render_meta(entry: MetaEntry) -> String {
  case string.starts_with(entry.key, "og:") {
    True ->
      "<meta property='"
      <> escape(entry.key)
      <> "' content='"
      <> escape(entry.value)
      <> "'>"

    False ->
      "<meta name='"
      <> escape(entry.key)
      <> "' content='"
      <> escape(entry.value)
      <> "'>"
  }
}

/// The Fediverse creator `<meta>` tag, or an empty string if not configured.
fn fediverse_meta(creator: Option(String)) -> String {
  case creator {
    option.Some(handle) ->
      "<meta name='fediverse:creator' content='" <> escape(handle) <> "'>"

    option.None -> ""
  }
}

/// Escape a value for use inside single-quoted HTML attributes or element text.
///
/// The shell's own static markup needs no escaping, but the title, the site
/// description, and any frontmatter-supplied meta entries all originate in
/// user-authored TOML and Markdown, so they must not be able to break out of
/// the attribute they sit in.
fn escape(value: String) -> String {
  value
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("'", "&#39;")
  |> string.replace("\"", "&quot;")
}
