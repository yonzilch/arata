//// Site metadata: SEO, analytics, and comments configuration, mirroring
//// apollo's `config.toml` `[extra]` block.
////
//// This extends the basic `config.Config` with the site-wide settings that
//// the head builder, analytics FFI, and comments view consume. The values
//// are normally loaded from `config.toml`; here they are hardcoded defaults
//// (Phase 17 replaces them with JSON loading).

import gleam/option.{type Option, None}

/// Analytics provider configuration.
pub type Analytics {
  GoatCounter(data_goatcounter: String, src: String)
  Liwan(data_entity: String, src: String)
  Umami(website_id: String, src: String)
  AnalyticsDisabled
}

/// Comments provider configuration (per-page, controlled by frontmatter).
pub type CommentsConfig {
  /// Giscus: repo, repo-id, category, category-id.
  Giscus(repo: String, repo_id: String, category: String, category_id: String)
  /// Utterances: repo.
  Utterances(repo: String)
  CommentsDisabled
}

/// Site-level metadata for SEO and integrations.
pub type SiteMeta {
  SiteMeta(
    base_url: String,
    title: String,
    description: String,
    analytics: Analytics,
    comments: CommentsConfig,
    fediverse_creator: Option(String),
    /// Whether to emit RSS/Atom feeds during the build. When `False`, the
    /// pipeline skips writing `dist/atom.xml` and `dist/rss.xml` and omits the
    /// feed `<link>` tags from `index.html`. Defaults to `True`. The pipeline
    /// reads this field because it operates on `SiteMeta`, not `config.Config`.
    rss_enabled: Bool,
  )
}

/// Hardcoded default site metadata. Phase 17 replaces this with JSON loading.
pub fn default() -> SiteMeta {
  SiteMeta(
    base_url: "https://arata.example.com",
    title: "arata",
    description: "A modern and minimalistic blog theme powered by Gleam and Lustre.",
    analytics: AnalyticsDisabled,
    comments: CommentsDisabled,
    fediverse_creator: None,
    rss_enabled: True,
  )
}
