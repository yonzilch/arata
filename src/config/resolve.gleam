//// Resolve raw user configuration into trusted build and runtime values.
////
//// This module:
////
////   - merges `RawConfig` with Arata's built-in defaults;
////   - canonicalizes the public base URL;
////   - derives `base_path` exclusively from `base_url`;
////   - resolves internal menu, social, and asset paths;
////   - constructs analytics and comments provider values;
////   - creates synchronized `Config` and `SiteMeta` values.
////
//// This module does not:
////
////   - read `content/arata.toml`;
////   - parse TOML;
////   - validate unknown TOML keys;
////   - validate referenced files under `static/`;
////   - serialize runtime configuration.
////
//// The resolver rejects incomplete collection entries and provider
//// configurations instead of silently replacing invalid user input with
//// defaults.
////
//// This module imports the existing top-level `config` module to construct the
//// current public `Config`, `MenuItem`, `Social`, and `Fonts` types. The public
//// `config` module must not import `config/resolve`, otherwise the modules would
//// form a dependency cycle.

import config
import config/defaults
import config/error.{type ConfigError}
import config/raw.{
  type RawAnalytics, type RawAratafetch, type RawAssets, type RawComments,
  type RawConfig, type RawFeatures, type RawFonts, type RawLatestPosts,
  type RawMenuItem, type RawSite, type RawSocial, RawAratafetch, RawAssets,
  RawFeatures, RawFonts, RawLatestPosts, RawMenuItem, RawSite, RawSocial,
}
import data/site.{
  type Analytics, type CommentsConfig, type SiteMeta, AnalyticsDisabled,
  CommentsDisabled, Giscus, GoatCounter, Liwan, SiteMeta, Umami, Utterances,
}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// Default source path used in resolution diagnostics.
///
/// A future caller resolving another explicitly selected file should use
/// `resolve_from` so errors identify the actual source.
pub const default_source_path = "content/arata.toml"

/// Fully resolved configuration shared by build-time and runtime preparation.
///
/// `config` contains the existing SPA-facing configuration shape.
///
/// `site_meta` contains canonical build metadata used by feeds, sitemap,
/// crawler outputs, analytics, and comments.
///
/// Both values are created from the same resolved inputs so their title,
/// description, analytics, RSS state, and deployment path cannot drift.
pub type ResolvedConfig {
  ResolvedConfig(config: config.Config, site_meta: SiteMeta)
}

/// Resolve raw configuration using the canonical Arata configuration path.
pub fn resolve(raw: RawConfig) -> Result(ResolvedConfig, List(ConfigError)) {
  resolve_from(default_source_path, raw)
}

/// Resolve raw configuration loaded from a specific source path.
///
/// Missing scalar values inherit built-in defaults. Present values are
/// preserved after whitespace normalization where appropriate.
///
/// Present `menu` and `socials` lists replace the built-in lists completely.
/// In particular, `Some([])` remains an explicit empty list.
pub fn resolve_from(
  source_path: String,
  raw: RawConfig,
) -> Result(ResolvedConfig, List(ConfigError)) {
  let site = resolve_site(raw.site)
  let features = resolve_features(raw.features)
  let latest_posts = resolve_latest_posts(raw.latest_posts)
  let aratafetch = resolve_aratafetch(raw.aratafetch)
  let fonts = resolve_fonts(raw.fonts)
  let assets = resolve_assets(raw.assets)

  let analytics_result = resolve_analytics(source_path, raw.analytics)

  let comments_result = resolve_comments(source_path, raw.comments)

  let menu_result = resolve_menu(source_path, raw.menu, site.base_path)

  let socials_result =
    resolve_socials(source_path, raw.socials, site.base_path, features.rss)

  let errors =
    []
    |> append_result_errors(analytics_result)
    |> append_result_errors(comments_result)
    |> append_result_errors(menu_result)
    |> append_result_errors(socials_result)

  case errors {
    [] -> {
      let assert Ok(analytics) = analytics_result
      let assert Ok(comments) = comments_result
      let assert Ok(menu) = menu_result
      let assert Ok(socials) = socials_result

      let runtime_config =
        config.Config(
          title: site.title,
          description: site.description,
          base_path: site.base_path,
          menu: menu,
          socials: socials,
          logo: resolve_optional_asset_path(site.base_path, site.logo),
          favicon: resolve_optional_asset_path(site.base_path, site.favicon),
          rss_enabled: features.rss,
          fonts: config.Fonts(
            text: fonts.text,
            header: fonts.header,
            code: fonts.code,
          ),
          search_enabled: features.search,
          navbar_fixed: features.navbar_fixed,
          analytics: analytics,
          mathjax_enabled: features.mathjax,
          mathjax_cdn_url: resolve_runtime_asset_url(
            site.base_path,
            assets.mathjax_url,
          ),
          mermaid_enabled: features.mermaid,
          mermaid_cdn_url: resolve_runtime_asset_url(
            site.base_path,
            assets.mermaid_url,
          ),
          syntax_highlight_enabled: features.syntax_highlight,
          syntax_highlight_cdn_url: resolve_runtime_asset_url(
            site.base_path,
            assets.syntax_highlight_url,
          ),
          sidebar_enabled: features.sidebar,
          floating_buttons_enabled: features.floating_buttons,
          aratafetch_enabled: features.aratafetch,
          aratafetch_maintained_for: aratafetch.maintained_for,
          lightbox_enabled: features.lightbox,
          latest_posts_enabled: features.latest_posts,
          latest_posts_count: latest_posts.count,
        )

      let site_meta =
        SiteMeta(
          base_url: site.base_url,
          title: site.title,
          description: site.description,
          analytics: analytics,
          comments: comments,
          fediverse_creator: site.fediverse_creator,
          rss_enabled: features.rss,
        )

      Ok(ResolvedConfig(config: runtime_config, site_meta: site_meta))
    }

    _ -> Error(errors)
  }
}

/// Return the existing SPA-facing configuration from a resolved value.
pub fn runtime_config(resolved: ResolvedConfig) -> config.Config {
  resolved.config
}

/// Return the build-time site metadata from a resolved value.
pub fn site_meta(resolved: ResolvedConfig) -> SiteMeta {
  resolved.site_meta
}

type ResolvedSite {
  ResolvedSite(
    base_url: String,
    base_path: String,
    title: String,
    description: String,
    logo: Option(String),
    favicon: Option(String),
    fediverse_creator: Option(String),
  )
}

type ResolvedFeatures {
  ResolvedFeatures(
    rss: Bool,
    search: Bool,
    navbar_fixed: Bool,
    mathjax: Bool,
    mermaid: Bool,
    syntax_highlight: Bool,
    sidebar: Bool,
    floating_buttons: Bool,
    aratafetch: Bool,
    lightbox: Bool,
    latest_posts: Bool,
  )
}

type ResolvedLatestPosts {
  ResolvedLatestPosts(count: Int)
}

type ResolvedAratafetch {
  ResolvedAratafetch(maintained_for: Option(String))
}

type ResolvedFonts {
  ResolvedFonts(text: String, header: String, code: String)
}

type ResolvedAssets {
  ResolvedAssets(
    mathjax_url: String,
    mermaid_url: String,
    syntax_highlight_url: String,
  )
}

fn resolve_site(raw: Option(RawSite)) -> ResolvedSite {
  let raw = case raw {
    Some(value) -> value

    None ->
      RawSite(
        base_url: None,
        title: None,
        description: None,
        logo: None,
        favicon: None,
        fediverse_creator: None,
      )
  }

  let base_url =
    raw.base_url
    |> unwrap(defaults.base_url())
    |> config.canonical_base_url

  ResolvedSite(
    base_url: base_url,
    base_path: config.base_path_from_url(base_url),
    title: unwrap(raw.title, defaults.title()),
    description: unwrap(raw.description, defaults.description()),
    logo: resolve_optional_string(raw.logo, defaults.logo()),
    favicon: resolve_optional_string(raw.favicon, defaults.favicon()),
    fediverse_creator: resolve_optional_string(
      raw.fediverse_creator,
      defaults.fediverse_creator(),
    ),
  )
}

fn resolve_features(raw: Option(RawFeatures)) -> ResolvedFeatures {
  let raw = case raw {
    Some(value) -> value

    None ->
      RawFeatures(
        rss: None,
        search: None,
        navbar_fixed: None,
        mathjax: None,
        mermaid: None,
        syntax_highlight: None,
        sidebar: None,
        floating_buttons: None,
        aratafetch: None,
        lightbox: None,
        latest_posts: None,
      )
  }

  ResolvedFeatures(
    rss: unwrap(raw.rss, defaults.rss_enabled()),
    search: unwrap(raw.search, defaults.search_enabled()),
    navbar_fixed: unwrap(raw.navbar_fixed, defaults.navbar_fixed()),
    mathjax: unwrap(raw.mathjax, defaults.mathjax_enabled()),
    mermaid: unwrap(raw.mermaid, defaults.mermaid_enabled()),
    syntax_highlight: unwrap(
      raw.syntax_highlight,
      defaults.syntax_highlight_enabled(),
    ),
    sidebar: unwrap(raw.sidebar, defaults.sidebar_enabled()),
    floating_buttons: unwrap(
      raw.floating_buttons,
      defaults.floating_buttons_enabled(),
    ),
    aratafetch: unwrap(raw.aratafetch, defaults.aratafetch_enabled()),
    lightbox: unwrap(raw.lightbox, defaults.lightbox_enabled()),
    latest_posts: unwrap(raw.latest_posts, defaults.latest_posts_enabled()),
  )
}

fn resolve_latest_posts(raw: Option(RawLatestPosts)) -> ResolvedLatestPosts {
  let raw = case raw {
    Some(value) -> value
    None -> RawLatestPosts(count: None)
  }

  ResolvedLatestPosts(count: unwrap(raw.count, defaults.latest_posts_count()))
}

fn resolve_aratafetch(raw: Option(RawAratafetch)) -> ResolvedAratafetch {
  let raw = case raw {
    Some(value) -> value
    None -> RawAratafetch(maintained_for: None)
  }

  ResolvedAratafetch(maintained_for: resolve_optional_string(
    raw.maintained_for,
    defaults.aratafetch_maintained_for(),
  ))
}

fn resolve_fonts(raw: Option(RawFonts)) -> ResolvedFonts {
  let raw = case raw {
    Some(value) -> value

    None -> RawFonts(text: None, header: None, code: None)
  }

  ResolvedFonts(
    text: unwrap(raw.text, defaults.text_font()),
    header: unwrap(raw.header, defaults.header_font()),
    code: unwrap(raw.code, defaults.code_font()),
  )
}

fn resolve_assets(raw: Option(RawAssets)) -> ResolvedAssets {
  let raw = case raw {
    Some(value) -> value

    None ->
      RawAssets(
        mathjax_url: None,
        mermaid_url: None,
        syntax_highlight_url: None,
      )
  }

  ResolvedAssets(
    mathjax_url: unwrap(raw.mathjax_url, defaults.mathjax_url()),
    mermaid_url: unwrap(raw.mermaid_url, defaults.mermaid_url()),
    syntax_highlight_url: unwrap(
      raw.syntax_highlight_url,
      defaults.syntax_highlight_url(),
    ),
  )
}

fn resolve_menu(
  source_path: String,
  raw: Option(List(RawMenuItem)),
  base_path: String,
) -> Result(List(config.MenuItem), List(ConfigError)) {
  case raw {
    None ->
      defaults.menu()
      |> list.map(fn(item) {
        let #(name, url) = item

        config.MenuItem(name: name, url: resolve_navigation_url(base_path, url))
      })
      |> Ok

    Some(items) -> resolve_menu_items(source_path, items, base_path, 0)
  }
}

fn resolve_menu_items(
  source_path: String,
  items: List(RawMenuItem),
  base_path: String,
  index: Int,
) -> Result(List(config.MenuItem), List(ConfigError)) {
  case items {
    [] -> Ok([])

    [item, ..rest] -> {
      let item_result = resolve_menu_item(source_path, item, base_path, index)

      let rest_result =
        resolve_menu_items(source_path, rest, base_path, index + 1)

      combine_item_and_rest(item_result, rest_result)
    }
  }
}

fn resolve_menu_item(
  source_path: String,
  item: RawMenuItem,
  base_path: String,
  index: Int,
) -> Result(config.MenuItem, List(ConfigError)) {
  let section = "menu[" <> int.to_string(index) <> "]"

  let name_result = require_string(source_path, section, "name", item.name)

  let url_result = require_string(source_path, section, "url", item.url)

  case name_result, url_result {
    Ok(name), Ok(url) ->
      Ok(config.MenuItem(
        name: name,
        url: resolve_navigation_url(base_path, url),
      ))

    _, _ ->
      Error(
        []
        |> append_result_errors(name_result)
        |> append_result_errors(url_result),
      )
  }
}

fn resolve_socials(
  source_path: String,
  raw: Option(List(RawSocial)),
  base_path: String,
  rss_enabled: Bool,
) -> Result(List(config.Social), List(ConfigError)) {
  let user_socials_result = case raw {
    None ->
      defaults.socials()
      |> list.map(fn(item) {
        let #(name, url, icon) = item

        config.Social(
          name: name,
          url: resolve_navigation_url(base_path, url),
          icon: icon,
        )
      })
      |> Ok

    Some(items) -> resolve_social_items(source_path, items, base_path, 0)
  }

  case user_socials_result {
    Error(errors) -> Error(errors)

    Ok(user_socials) -> {
      let managed_rss = case rss_enabled {
        False -> []

        True -> {
          let #(name, url, icon) = defaults.rss_social()

          [
            config.Social(
              name: name,
              url: resolve_navigation_url(base_path, url),
              icon: icon,
            ),
          ]
        }
      }

      Ok(list.append(managed_rss, user_socials))
    }
  }
}

fn resolve_social_items(
  source_path: String,
  items: List(RawSocial),
  base_path: String,
  index: Int,
) -> Result(List(config.Social), List(ConfigError)) {
  case items {
    [] -> Ok([])

    [item, ..rest] -> {
      let item_result = resolve_social_item(source_path, item, base_path, index)

      let rest_result =
        resolve_social_items(source_path, rest, base_path, index + 1)

      combine_item_and_rest(item_result, rest_result)
    }
  }
}

fn resolve_social_item(
  source_path: String,
  item: RawSocial,
  base_path: String,
  index: Int,
) -> Result(config.Social, List(ConfigError)) {
  let section = "socials[" <> int.to_string(index) <> "]"

  let name_result = require_string(source_path, section, "name", item.name)

  let url_result = require_string(source_path, section, "url", item.url)

  let icon_result = require_string(source_path, section, "icon", item.icon)

  case name_result, url_result, icon_result {
    Ok(name), Ok(url), Ok(icon) ->
      Ok(config.Social(
        name: name,
        url: resolve_navigation_url(base_path, url),
        icon: icon,
      ))

    _, _, _ ->
      Error(
        []
        |> append_result_errors(name_result)
        |> append_result_errors(url_result)
        |> append_result_errors(icon_result),
      )
  }
}

fn resolve_analytics(
  source_path: String,
  raw: Option(RawAnalytics),
) -> Result(Analytics, List(ConfigError)) {
  case raw {
    None -> Ok(defaults.analytics())

    Some(raw) -> {
      let provider =
        raw.provider
        |> unwrap("disabled")
        |> normalize_provider

      case provider {
        "disabled" -> Ok(AnalyticsDisabled)

        "goatcounter" -> resolve_goatcounter(source_path, raw)

        "umami" -> resolve_umami(source_path, raw)

        "liwan" -> resolve_liwan(source_path, raw)

        _ ->
          Error([
            error.validation(
              source_path,
              Some("analytics"),
              Some("provider"),
              Some("disabled, goatcounter, umami, or liwan"),
              Some(provider),
              "unsupported analytics provider",
            ),
          ])
      }
    }
  }
}

fn resolve_goatcounter(
  source_path: String,
  raw: RawAnalytics,
) -> Result(Analytics, List(ConfigError)) {
  let data_result =
    require_string(
      source_path,
      "analytics",
      "data_goatcounter",
      raw.data_goatcounter,
    )

  let src_result = require_string(source_path, "analytics", "src", raw.src)

  case data_result, src_result {
    Ok(data_goatcounter), Ok(src) ->
      Ok(GoatCounter(data_goatcounter: data_goatcounter, src: src))

    _, _ ->
      Error(
        []
        |> append_result_errors(data_result)
        |> append_result_errors(src_result),
      )
  }
}

fn resolve_umami(
  source_path: String,
  raw: RawAnalytics,
) -> Result(Analytics, List(ConfigError)) {
  let website_id_result =
    require_string(source_path, "analytics", "website_id", raw.website_id)

  let src_result = require_string(source_path, "analytics", "src", raw.src)

  case website_id_result, src_result {
    Ok(website_id), Ok(src) -> Ok(Umami(website_id: website_id, src: src))

    _, _ ->
      Error(
        []
        |> append_result_errors(website_id_result)
        |> append_result_errors(src_result),
      )
  }
}

fn resolve_liwan(
  source_path: String,
  raw: RawAnalytics,
) -> Result(Analytics, List(ConfigError)) {
  let entity_result =
    require_string(source_path, "analytics", "data_entity", raw.data_entity)

  let src_result = require_string(source_path, "analytics", "src", raw.src)

  case entity_result, src_result {
    Ok(data_entity), Ok(src) -> Ok(Liwan(data_entity: data_entity, src: src))

    _, _ ->
      Error(
        []
        |> append_result_errors(entity_result)
        |> append_result_errors(src_result),
      )
  }
}

fn resolve_comments(
  source_path: String,
  raw: Option(RawComments),
) -> Result(CommentsConfig, List(ConfigError)) {
  case raw {
    None -> Ok(defaults.comments())

    Some(raw) -> {
      let provider =
        raw.provider
        |> unwrap("disabled")
        |> normalize_provider

      case provider {
        "disabled" -> Ok(CommentsDisabled)

        "giscus" -> resolve_giscus(source_path, raw)

        "utterances" -> resolve_utterances(source_path, raw)

        _ ->
          Error([
            error.validation(
              source_path,
              Some("comments"),
              Some("provider"),
              Some("disabled, giscus, or utterances"),
              Some(provider),
              "unsupported comments provider",
            ),
          ])
      }
    }
  }
}

fn resolve_giscus(
  source_path: String,
  raw: RawComments,
) -> Result(CommentsConfig, List(ConfigError)) {
  let repo_result = require_string(source_path, "comments", "repo", raw.repo)

  let repo_id_result =
    require_string(source_path, "comments", "repo_id", raw.repo_id)

  let category_result =
    require_string(source_path, "comments", "category", raw.category)

  let category_id_result =
    require_string(source_path, "comments", "category_id", raw.category_id)

  case repo_result, repo_id_result, category_result, category_id_result {
    Ok(repo), Ok(repo_id), Ok(category), Ok(category_id) ->
      Ok(Giscus(
        repo: repo,
        repo_id: repo_id,
        category: category,
        category_id: category_id,
      ))

    _, _, _, _ ->
      Error(
        []
        |> append_result_errors(repo_result)
        |> append_result_errors(repo_id_result)
        |> append_result_errors(category_result)
        |> append_result_errors(category_id_result),
      )
  }
}

fn resolve_utterances(
  source_path: String,
  raw: RawComments,
) -> Result(CommentsConfig, List(ConfigError)) {
  case require_string(source_path, "comments", "repo", raw.repo) {
    Ok(repo) -> Ok(Utterances(repo: repo))

    Error(errors) -> Error(errors)
  }
}

fn require_string(
  source_path: String,
  section: String,
  key: String,
  value: Option(String),
) -> Result(String, List(ConfigError)) {
  case value {
    None ->
      Error([
        error.validation(
          source_path,
          Some(section),
          Some(key),
          Some("a non-empty string"),
          None,
          "required configuration value is missing",
        ),
      ])

    Some(value) -> {
      let value = string.trim(value)

      case value {
        "" ->
          Error([
            error.validation(
              source_path,
              Some(section),
              Some(key),
              Some("a non-empty string"),
              Some(""),
              "configuration value must not be empty",
            ),
          ])

        _ -> Ok(value)
      }
    }
  }
}

fn resolve_optional_string(
  raw: Option(String),
  default: Option(String),
) -> Option(String) {
  case raw {
    None -> default

    Some(value) -> {
      let value = string.trim(value)

      case value {
        "" -> None
        _ -> Some(value)
      }
    }
  }
}

fn resolve_optional_asset_path(
  base_path: String,
  path: Option(String),
) -> Option(String) {
  case path {
    None -> None

    Some(path) -> Some(resolve_runtime_asset_url(base_path, path))
  }
}

fn resolve_runtime_asset_url(base_path: String, url: String) -> String {
  let url = string.trim(url)

  case is_external_or_special_url(url) {
    True -> url
    False -> config.with_base_path(base_path, url)
  }
}

fn resolve_navigation_url(base_path: String, url: String) -> String {
  let url = string.trim(url)

  case is_external_or_special_url(url) {
    True -> url
    False -> config.with_base_path(base_path, url)
  }
}

fn is_external_or_special_url(url: String) -> Bool {
  string.starts_with(url, "https://")
  || string.starts_with(url, "http://")
  || string.starts_with(url, "//")
  || string.starts_with(url, "#")
  || string.starts_with(url, "mailto:")
  || string.starts_with(url, "tel:")
}

fn normalize_provider(provider: String) -> String {
  provider
  |> string.trim
  |> string.lowercase
}

fn unwrap(value: Option(a), default: a) -> a {
  case value {
    Some(value) -> value
    None -> default
  }
}

fn combine_item_and_rest(
  item: Result(a, List(ConfigError)),
  rest: Result(List(a), List(ConfigError)),
) -> Result(List(a), List(ConfigError)) {
  case item, rest {
    Ok(item), Ok(rest) -> Ok([item, ..rest])

    Error(item_errors), Ok(_) -> Error(item_errors)

    Ok(_), Error(rest_errors) -> Error(rest_errors)

    Error(item_errors), Error(rest_errors) ->
      Error(list.append(item_errors, rest_errors))
  }
}

fn append_result_errors(
  errors: List(ConfigError),
  value: Result(a, List(ConfigError)),
) -> List(ConfigError) {
  case value {
    Ok(_) -> errors
    Error(next_errors) -> list.append(errors, next_errors)
  }
}
