//// Browser-safe configuration derived from resolved Arata configuration.
////
//// This module defines the explicit boundary between build configuration and
//// configuration serialized into `content_index.json`.
////
//// Runtime configuration contains only public values required by the SPA:
////
////   - site identity and canonical URL;
////   - navigation and social links;
////   - public analytics and comments provider configuration;
////   - fonts and feature toggles;
////   - public runtime asset URLs;
////   - resolved feed availability and content mode.
////
//// Configuration source paths, parser diagnostics, validation state, and other
//// build-only data must never be added to `RuntimeConfig`.
////
//// All values in this module are browser-visible. They must not contain API
//// keys, private tokens, credentials, or other secrets.
////
//// This module does not:
////
////   - read or parse `content/arata.toml`;
////   - apply defaults;
////   - normalize paths;
////   - validate values;
////   - encode or decode JSON.
////
//// JSON serialization belongs at the content-index boundary. Browser-side JSON
//// decoding should reconstruct this type before the SPA starts.

import config
import config/resolve.{type ResolvedConfig}
import data/site.{type CommentsConfig}
import gleam/option.{type Option}

/// Public site metadata required by the browser.
///
/// Fields already present in `config.Config`, such as title, description,
/// analytics, feed mode, and derived RSS state, are not duplicated here.
/// Keeping one authoritative runtime value prevents those fields from drifting
/// after decoding.
///
/// `base_url` is retained because the browser may require the canonical public
/// URL for metadata and absolute URL construction.
///
/// `comments` is retained because comment integrations are rendered by the SPA.
///
/// `fediverse_creator` is retained for runtime-managed metadata.
pub type RuntimeSite {
  RuntimeSite(
    base_url: String,
    comments: CommentsConfig,
    fediverse_creator: Option(String),
  )
}

/// Complete browser-visible Arata configuration.
///
/// `application` uses the existing `config.Config` type consumed by views and
/// effects. This allows configuration changes to preserve one authoritative
/// application model instead of introducing a duplicated runtime type.
///
/// The application configuration includes both:
///
/// - `feed_mode`, which distinguishes full, summary, and disabled feeds;
/// - `rss_enabled`, which remains a compatibility value derived from
///   `feed_mode`.
///
/// Runtime consumers that only need to determine feed availability should use
/// `feeds_enabled`. Consumers that need content-mode semantics should use
/// `feed_mode`.
///
/// `site` contains the remaining public metadata currently carried only by
/// `SiteMeta`.
pub type RuntimeConfig {
  RuntimeConfig(application: config.Config, site: RuntimeSite)
}

/// Project the browser-safe subset from fully resolved configuration.
///
/// This function must be called only after configuration resolution and
/// validation have succeeded.
///
/// Feed state is not recomputed here. The resolver is the single authority that
/// derives `rss_enabled` from `feed_mode`, ensuring that the serialized runtime
/// configuration cannot independently choose conflicting values.
pub fn from_resolved(resolved: ResolvedConfig) -> RuntimeConfig {
  let application = resolve.runtime_config(resolved)
  let metadata = resolve.site_meta(resolved)

  RuntimeConfig(
    application: application,
    site: RuntimeSite(
      base_url: metadata.base_url,
      comments: metadata.comments,
      fediverse_creator: metadata.fediverse_creator,
    ),
  )
}

/// Return the application configuration consumed by SPA views and effects.
pub fn application(runtime: RuntimeConfig) -> config.Config {
  runtime.application
}

/// Return the browser-safe site metadata.
pub fn site(runtime: RuntimeConfig) -> RuntimeSite {
  runtime.site
}

/// Return the canonical public URL of the deployed site.
pub fn base_url(runtime: RuntimeConfig) -> String {
  runtime.site.base_url
}

/// Return the public comments provider configuration.
pub fn comments(runtime: RuntimeConfig) -> CommentsConfig {
  runtime.site.comments
}

/// Return the optional Fediverse creator attribution.
pub fn fediverse_creator(runtime: RuntimeConfig) -> Option(String) {
  runtime.site.fediverse_creator
}

/// Return the resolved feed content mode.
///
/// The mode has already passed through default resolution and validation before
/// entering the runtime configuration.
pub fn feed_mode(runtime: RuntimeConfig) -> config.FeedMode {
  runtime.application.feed_mode
}

/// Return whether Atom and RSS feeds are enabled.
///
/// This compatibility accessor derives availability from `feed_mode` rather
/// than trusting a separately mutable runtime value.
pub fn feeds_enabled(runtime: RuntimeConfig) -> Bool {
  config.feeds_enabled(runtime.application.feed_mode)
}
