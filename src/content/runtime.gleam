//// Runtime content: the SPA's browser-safe content source.
////
//// The SPA fetches the build-generated `content_index.json` instead of reading
//// Markdown files or `content/arata.toml` in the browser.
////
//// The content index contains:
////
////   - resolved browser-safe configuration;
////   - posts;
////   - pages;
////   - homepage content;
////   - friend links;
////   - projects.
////
//// Runtime configuration is decoded from the same content index as content so
//// the SPA retains Arata's single-fetch startup invariant.
////
//// Important compatibility invariants:
////
////   - friend-link `weight` defaults to 999 for older generated indexes;
////   - optional post, page, link, and project fields retain safe defaults;
////   - missing `feed_mode` falls back to the legacy `rss_enabled` value;
////   - configuration decoding is strict because partial runtime configuration
////     could produce inconsistent feature behavior.
////
//// The initial `content_index.json` request uses the resolved deployment base
//// path embedded in the generated HTML shell. This avoids depending on
//// compiled configuration defaults before runtime configuration has loaded.

import config
import config/runtime.{
  type RuntimeConfig, type RuntimeSite, RuntimeConfig, RuntimeSite,
}
import data/link.{type Link, Link}
import data/page.{type Page, Page}
import data/post.{type Post, type TocEntry, Post, TocEntry}
import data/project.{type Project, Project}
import data/site.{
  type Analytics, type CommentsConfig, AnalyticsDisabled, CommentsDisabled,
  Giscus, GoatCounter, Liwan, Umami, Utterances,
}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option
import gleam/order.{type Order, Eq}
import gleam/string
import lustre/effect.{type Effect}
import rsvp

const default_link_weight = 999

/// All runtime data loaded from `content_index.json`.
///
/// Configuration and content are kept together so every runtime consumer uses
/// values produced by the same successful build.
pub type Content {
  Content(
    config: RuntimeConfig,
    posts: List(Post),
    pages: List(Page),
    homepage: Page,
    links: List(Link),
    projects: List(Project),
  )
}

/// Messages produced by the content-loading effect.
pub type ContentMsg {
  ContentLoaded(result: Result(Content, rsvp.Error(String)))
}

/// Fetch and decode `content_index.json`.
///
/// The request URL uses the compiled default base path only as a bootstrap
/// value. After decoding, the SPA must use `Content.config` for all runtime
/// rendering, routing, feature toggles, and public integration settings.
pub fn load() -> Effect(ContentMsg) {
  let handler =
    rsvp.expect_json(decode_content_index(), fn(result) {
      ContentLoaded(result)
    })

  let url = config.with_base_path(arata_base_path(), "/content_index.json")

  rsvp.get(url, handler)
}

/// Return the deployment base path embedded in the generated HTML shell.
///
/// The build pipeline writes the resolved value from `content/arata.toml` into
/// both `index.html` and `404.html`. An empty value represents a root
/// deployment.
///
/// The browser implementation falls back to an empty string when the metadata
/// is unavailable, producing the root request path `/content_index.json`.
@external(javascript, "../ffi/browser.ffi.mjs", "arata_base_path")
fn arata_base_path() -> String

/// Decode the complete content index.
fn decode_content_index() -> decode.Decoder(Content) {
  use runtime_config <- decode.field("config", decode_runtime_config())
  use posts <- decode.field("posts", decode.list(decode_post()))
  use pages <- decode.field("pages", decode.list(decode_page()))
  use homepage <- decode.field("homepage", decode_page())
  use links <- decode.field("links", decode.list(decode_link()))
  use projects <- decode.field("projects", decode.list(decode_project()))

  let ordered_links = sort_links(links)

  decode.success(Content(
    config: runtime_config,
    posts: posts,
    pages: pages,
    homepage: homepage,
    links: ordered_links,
    projects: projects,
  ))
}

/// Decode the browser-safe runtime configuration.
///
/// The build encoder emits two explicit sections:
///
///   config.application
///   config.site
fn decode_runtime_config() -> decode.Decoder(RuntimeConfig) {
  use application <- decode.field("application", decode_application_config())

  use site <- decode.field("site", decode_runtime_site())

  decode.success(RuntimeConfig(application: application, site: site))
}

/// Decode the application configuration consumed by views and effects.
///
/// `feed_mode` is optional for compatibility with older generated content
/// indexes. When absent, the legacy `rss_enabled` value maps to:
///
///   true  -> Summary
///   false -> Disabled
///
/// When present, `feed_mode` is authoritative and `rss_enabled` is derived from
/// it so the two runtime values cannot disagree.
fn decode_application_config() -> decode.Decoder(config.Config) {
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.string)
  use base_path <- decode.field("base_path", decode.string)
  use menu <- decode.field("menu", decode.list(decode_menu_item()))
  use socials <- decode.field("socials", decode.list(decode_social()))
  use logo <- decode.optional_field(
    "logo",
    option.None,
    decode.optional(decode.string),
  )
  use favicon <- decode.optional_field(
    "favicon",
    option.None,
    decode.optional(decode.string),
  )
  use legacy_rss_enabled <- decode.field("rss_enabled", decode.bool)
  use feed_mode <- decode.optional_field(
    "feed_mode",
    config.feed_mode_from_enabled(legacy_rss_enabled),
    decode_feed_mode(),
  )
  use fonts <- decode.field("fonts", decode_fonts())
  use search_enabled <- decode.field("search_enabled", decode.bool)
  use navbar_fixed <- decode.field("navbar_fixed", decode.bool)
  use analytics <- decode.field("analytics", decode_analytics())
  use mathjax_enabled <- decode.field("mathjax_enabled", decode.bool)
  use mathjax_cdn_url <- decode.field("mathjax_cdn_url", decode.string)
  use mermaid_enabled <- decode.field("mermaid_enabled", decode.bool)
  use mermaid_cdn_url <- decode.field("mermaid_cdn_url", decode.string)
  use syntax_highlight_enabled <- decode.field(
    "syntax_highlight_enabled",
    decode.bool,
  )
  use syntax_highlight_cdn_url <- decode.field(
    "syntax_highlight_cdn_url",
    decode.string,
  )
  use sidebar_enabled <- decode.field("sidebar_enabled", decode.bool)
  use floating_buttons_enabled <- decode.field(
    "floating_buttons_enabled",
    decode.bool,
  )
  use aratafetch_enabled <- decode.field("aratafetch_enabled", decode.bool)
  use aratafetch_maintained_for <- decode.optional_field(
    "aratafetch_maintained_for",
    option.None,
    decode.optional(decode.string),
  )
  use lightbox_enabled <- decode.field("lightbox_enabled", decode.bool)
  use latest_posts_enabled <- decode.field("latest_posts_enabled", decode.bool)
  use latest_posts_count <- decode.field("latest_posts_count", decode.int)

  decode.success(config.Config(
    title: title,
    description: description,
    base_path: base_path,
    menu: menu,
    socials: socials,
    logo: logo,
    favicon: favicon,
    rss_enabled: config.feeds_enabled(feed_mode),
    feed_mode: feed_mode,
    fonts: fonts,
    search_enabled: search_enabled,
    navbar_fixed: navbar_fixed,
    analytics: analytics,
    mathjax_enabled: mathjax_enabled,
    mathjax_cdn_url: mathjax_cdn_url,
    mermaid_enabled: mermaid_enabled,
    mermaid_cdn_url: mermaid_cdn_url,
    syntax_highlight_enabled: syntax_highlight_enabled,
    syntax_highlight_cdn_url: syntax_highlight_cdn_url,
    sidebar_enabled: sidebar_enabled,
    floating_buttons_enabled: floating_buttons_enabled,
    aratafetch_enabled: aratafetch_enabled,
    aratafetch_maintained_for: aratafetch_maintained_for,
    lightbox_enabled: lightbox_enabled,
    latest_posts_enabled: latest_posts_enabled,
    latest_posts_count: latest_posts_count,
  ))
}

/// Decode a serialized feed content mode.
fn decode_feed_mode() -> decode.Decoder(config.FeedMode) {
  decode.string
  |> decode.then(fn(mode) {
    case string.lowercase(mode) {
      "full" -> decode.success(config.Full)

      "summary" -> decode.success(config.Summary)

      "disabled" -> decode.success(config.Disabled)

      _ -> decode.failure(config.Disabled, "unsupported feed mode: " <> mode)
    }
  })
}

/// Decode browser-safe site metadata.
fn decode_runtime_site() -> decode.Decoder(RuntimeSite) {
  use base_url <- decode.field("base_url", decode.string)
  use comments <- decode.field("comments", decode_comments())
  use fediverse_creator <- decode.optional_field(
    "fediverse_creator",
    option.None,
    decode.optional(decode.string),
  )

  decode.success(RuntimeSite(
    base_url: base_url,
    comments: comments,
    fediverse_creator: fediverse_creator,
  ))
}

fn decode_menu_item() -> decode.Decoder(config.MenuItem) {
  use name <- decode.field("name", decode.string)
  use url <- decode.field("url", decode.string)

  decode.success(config.MenuItem(name: name, url: url))
}

fn decode_social() -> decode.Decoder(config.Social) {
  use name <- decode.field("name", decode.string)
  use url <- decode.field("url", decode.string)
  use icon <- decode.field("icon", decode.string)

  decode.success(config.Social(name: name, url: url, icon: icon))
}

fn decode_fonts() -> decode.Decoder(config.Fonts) {
  use text <- decode.field("text", decode.string)
  use header <- decode.field("header", decode.string)
  use code <- decode.field("code", decode.string)

  decode.success(config.Fonts(text: text, header: header, code: code))
}

/// Decode analytics using the explicit provider discriminator.
fn decode_analytics() -> decode.Decoder(Analytics) {
  use provider <- decode.field("provider", decode.string)

  case string.lowercase(provider) {
    "disabled" -> decode.success(AnalyticsDisabled)

    "goatcounter" -> {
      use data_goatcounter <- decode.field("data_goatcounter", decode.string)
      use src <- decode.field("src", decode.string)

      decode.success(GoatCounter(data_goatcounter: data_goatcounter, src: src))
    }

    "umami" -> {
      use website_id <- decode.field("website_id", decode.string)
      use src <- decode.field("src", decode.string)

      decode.success(Umami(website_id: website_id, src: src))
    }

    "liwan" -> {
      use data_entity <- decode.field("data_entity", decode.string)
      use src <- decode.field("src", decode.string)

      decode.success(Liwan(data_entity: data_entity, src: src))
    }

    _ ->
      decode.failure(
        AnalyticsDisabled,
        "unsupported analytics provider: " <> provider,
      )
  }
}

/// Decode comments configuration using the provider discriminator.
fn decode_comments() -> decode.Decoder(CommentsConfig) {
  use provider <- decode.field("provider", decode.string)

  case string.lowercase(provider) {
    "disabled" -> decode.success(CommentsDisabled)

    "giscus" -> {
      use repo <- decode.field("repo", decode.string)
      use repo_id <- decode.field("repo_id", decode.string)
      use category <- decode.field("category", decode.string)
      use category_id <- decode.field("category_id", decode.string)

      decode.success(Giscus(
        repo: repo,
        repo_id: repo_id,
        category: category,
        category_id: category_id,
      ))
    }

    "utterances" -> {
      use repo <- decode.field("repo", decode.string)

      decode.success(Utterances(repo: repo))
    }

    _ ->
      decode.failure(
        CommentsDisabled,
        "unsupported comments provider: " <> provider,
      )
  }
}

fn sort_links(links: List(Link)) -> List(Link) {
  list.sort(links, compare_links)
}

fn compare_links(a: Link, b: Link) -> Order {
  case int.compare(a.weight, b.weight) {
    Eq -> string.compare(string.lowercase(a.title), string.lowercase(b.title))

    ordering -> ordering
  }
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
  use weight <- decode.optional_field("weight", default_link_weight, decode.int)

  decode.success(Link(
    title: title,
    url: url,
    description: description,
    image: image,
    weight: weight,
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
