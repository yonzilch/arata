//// Encode browser-safe Arata configuration as JSON.
////
//// The resulting object is intended to be embedded under the `config` field
//// of `content_index.json`.
////
//// This module serializes only `config/runtime.RuntimeConfig`. It must not
//// accept raw configuration, loader state, parser diagnostics, or other
//// build-only values.
////
//// All serialized values are public and browser-visible. Configuration must
//// not contain API keys, private tokens, credentials, or other secrets.
////
//// This module does not:
////
////   - write files;
////   - serialize the complete content index;
////   - parse or decode JSON;
////   - load or resolve TOML configuration.

import config
import config/runtime.{type RuntimeConfig, type RuntimeSite}
import data/site.{
  type Analytics, type CommentsConfig, AnalyticsDisabled, CommentsDisabled,
  Giscus, GoatCounter, Liwan, Umami, Utterances,
}
import gleam/json
import gleam/option.{type Option, None, Some}

/// Encode runtime configuration as a JSON value.
///
/// The returned object can be inserted directly into the root content-index
/// object:
///
///   #("config", config_encoder.to_json(runtime_config))
pub fn to_json(runtime: RuntimeConfig) -> json.Json {
  json.object([
    #("application", application_to_json(runtime.application)),
    #("site", site_to_json(runtime.site)),
  ])
}

/// Encode runtime configuration directly as a JSON string.
///
/// The build pipeline normally uses `to_json` so configuration can be composed
/// into `content_index.json` without an intermediate encode/decode cycle.
pub fn to_string(runtime: RuntimeConfig) -> String {
  runtime
  |> to_json
  |> json.to_string
}

/// Encode the application configuration consumed by SPA views and effects.
pub fn application_to_json(application: config.Config) -> json.Json {
  json.object([
    #("title", json.string(application.title)),
    #("description", json.string(application.description)),
    #("base_path", json.string(application.base_path)),
    #("menu", json.array(application.menu, menu_item_to_json)),
    #("socials", json.array(application.socials, social_to_json)),
    #("logo", option_string_to_json(application.logo)),
    #("favicon", option_string_to_json(application.favicon)),
    #("rss_enabled", json.bool(application.rss_enabled)),
    #("fonts", fonts_to_json(application.fonts)),
    #("search_enabled", json.bool(application.search_enabled)),
    #("navbar_fixed", json.bool(application.navbar_fixed)),
    #("analytics", analytics_to_json(application.analytics)),
    #("mathjax_enabled", json.bool(application.mathjax_enabled)),
    #("mathjax_cdn_url", json.string(application.mathjax_cdn_url)),
    #("mermaid_enabled", json.bool(application.mermaid_enabled)),
    #("mermaid_cdn_url", json.string(application.mermaid_cdn_url)),
    #(
      "syntax_highlight_enabled",
      json.bool(application.syntax_highlight_enabled),
    ),
    #(
      "syntax_highlight_cdn_url",
      json.string(application.syntax_highlight_cdn_url),
    ),
    #("sidebar_enabled", json.bool(application.sidebar_enabled)),
    #(
      "floating_buttons_enabled",
      json.bool(application.floating_buttons_enabled),
    ),
    #("aratafetch_enabled", json.bool(application.aratafetch_enabled)),
    #(
      "aratafetch_maintained_for",
      option_string_to_json(application.aratafetch_maintained_for),
    ),
    #("lightbox_enabled", json.bool(application.lightbox_enabled)),
    #("latest_posts_enabled", json.bool(application.latest_posts_enabled)),
    #("latest_posts_count", json.int(application.latest_posts_count)),
  ])
}

/// Encode the browser-safe site metadata.
pub fn site_to_json(site: RuntimeSite) -> json.Json {
  json.object([
    #("base_url", json.string(site.base_url)),
    #("comments", comments_to_json(site.comments)),
    #("fediverse_creator", option_string_to_json(site.fediverse_creator)),
  ])
}

/// Encode one navigation item.
pub fn menu_item_to_json(item: config.MenuItem) -> json.Json {
  json.object([
    #("name", json.string(item.name)),
    #("url", json.string(item.url)),
  ])
}

/// Encode one social link.
pub fn social_to_json(social: config.Social) -> json.Json {
  json.object([
    #("name", json.string(social.name)),
    #("url", json.string(social.url)),
    #("icon", json.string(social.icon)),
  ])
}

/// Encode font-family configuration.
pub fn fonts_to_json(fonts: config.Fonts) -> json.Json {
  json.object([
    #("text", json.string(fonts.text)),
    #("header", json.string(fonts.header)),
    #("code", json.string(fonts.code)),
  ])
}

/// Encode the selected analytics provider.
///
/// The `provider` discriminator is always emitted so browser-side decoding can
/// select the correct constructor without inferring it from optional fields.
pub fn analytics_to_json(analytics: Analytics) -> json.Json {
  case analytics {
    AnalyticsDisabled ->
      json.object([
        #("provider", json.string("disabled")),
      ])

    GoatCounter(data_goatcounter:, src:) ->
      json.object([
        #("provider", json.string("goatcounter")),
        #("data_goatcounter", json.string(data_goatcounter)),
        #("src", json.string(src)),
      ])

    Umami(website_id:, src:) ->
      json.object([
        #("provider", json.string("umami")),
        #("website_id", json.string(website_id)),
        #("src", json.string(src)),
      ])

    Liwan(data_entity:, src:) ->
      json.object([
        #("provider", json.string("liwan")),
        #("data_entity", json.string(data_entity)),
        #("src", json.string(src)),
      ])
  }
}

/// Encode the selected comments provider.
///
/// The current `CommentsConfig` data model exposes only the fields represented
/// by its constructors. Additional Giscus or Utterances options present in the
/// raw TOML model cannot be serialized until `data/site.CommentsConfig` is
/// extended to retain them.
pub fn comments_to_json(comments: CommentsConfig) -> json.Json {
  case comments {
    CommentsDisabled ->
      json.object([
        #("provider", json.string("disabled")),
      ])

    Giscus(repo:, repo_id:, category:, category_id:) ->
      json.object([
        #("provider", json.string("giscus")),
        #("repo", json.string(repo)),
        #("repo_id", json.string(repo_id)),
        #("category", json.string(category)),
        #("category_id", json.string(category_id)),
      ])

    Utterances(repo:) ->
      json.object([
        #("provider", json.string("utterances")),
        #("repo", json.string(repo)),
      ])
  }
}

fn option_string_to_json(value: Option(String)) -> json.Json {
  case value {
    Some(value) -> json.string(value)
    None -> json.null()
  }
}
