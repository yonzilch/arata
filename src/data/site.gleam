//// Site metadata shared by build-time SEO, feed, analytics, and comments
//// generation.
////
//// Runtime application configuration is represented by `config.Config`.
//// `SiteMeta` retains the build-facing values needed by feed, sitemap,
//// crawler, analytics, comments, and metadata generators.
////
//// Feed content behavior is not represented here. `config.FeedMode` is the
//// authoritative source for choosing full, summary, or disabled feed output.
//// `rss_enabled` is retained as a compatibility availability flag derived from
//// the resolved feed mode.
////
//// This module declares types only. Built-in values live in `config/defaults`
//// and are assembled by `config.site_meta()` and
//// `config/resolve.resolve`. Do not add literal site metadata here; it would
//// become a second source of truth that silently diverges from the framework
//// defaults.

import gleam/option.{type Option}

/// Analytics provider configuration.
pub type Analytics {
  GoatCounter(data_goatcounter: String, src: String)
  Liwan(data_entity: String, src: String)
  Umami(website_id: String, src: String)
  AnalyticsDisabled
}

/// Comments provider configuration.
pub type CommentsConfig {
  /// Giscus repository and discussion category configuration.
  Giscus(repo: String, repo_id: String, category: String, category_id: String)

  /// Utterances repository configuration.
  Utterances(repo: String)

  CommentsDisabled
}

/// Site-level metadata for build output, SEO, and public integrations.
///
/// `rss_enabled` is a compatibility availability flag:
///
///   - `True` for full and summary feed modes;
///   - `False` for disabled feed mode.
///
/// It must be derived from the authoritative `config.FeedMode`. Consumers that
/// need to distinguish full content from summaries must use `Config.feed_mode`
/// instead.
pub type SiteMeta {
  SiteMeta(
    base_url: String,
    title: String,
    description: String,
    analytics: Analytics,
    comments: CommentsConfig,
    fediverse_creator: Option(String),
    rss_enabled: Bool,
  )
}
