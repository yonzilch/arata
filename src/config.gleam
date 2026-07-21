//// Public site configuration types and backward-compatible default accessors.
////
//// User-owned configuration is defined in:
////
////   content/arata.toml
////
//// The configuration pipeline loads that file, decodes it into `RawConfig`,
//// applies the built-in defaults from `config/defaults`, resolves deployment
//// paths, and validates the final configuration before the build writes any
//// output.
////
//// This top-level module remains the stable configuration API consumed by
//// existing views, effects, routes, and build modules. It owns the public
//// runtime types but delegates framework defaults and URL normalization to
//// their dedicated modules.
////
//// `default()` and `site_meta()` remain available for backward compatibility
//// and tests. Production build code should load and resolve configuration once
//// at the build entry point instead of calling these functions independently.
////
//// The `Social.icon` field is the filename without extension of an SVG under:
////
////   static/icons/social/
////
//// For example, `icon: "github"` resolves to:
////
////   /icons/social/github.svg

import config/defaults
import config/url as config_url
import data/site.{type Analytics, type SiteMeta, SiteMeta}
import gleam/list
import gleam/option.{type Option, None, Some}

/// A public social link rendered in the site header.
///
/// `icon` is the filename without the `.svg` extension under
/// `static/icons/social/`.
pub type Social {
  Social(name: String, url: String, icon: String)
}

/// A navigation item rendered in the site header.
///
/// Internal URLs are resolved against the deployment base path before they
/// enter this trusted configuration type.
pub type MenuItem {
  MenuItem(name: String, url: String)
}

/// Font-family configuration used by Arata's CSS custom properties.
///
/// Values are complete CSS `font-family` declarations.
///
/// Optional fonts users can configure include:
///
/// - Maple Font for programming ligatures;
/// - Sarasa Gothic for CJK-friendly text and code rendering.
pub type Fonts {
  Fonts(text: String, header: String, code: String)
}

/// Trusted application configuration consumed by the SPA.
///
/// Values of this type must already have passed through default resolution,
/// deployment-path normalization, and semantic validation.
///
/// Build-only metadata that is not directly consumed by application views and
/// effects remains in `data/site.SiteMeta`.
pub type Config {
  Config(
    title: String,
    description: String,
    /// Base path derived exclusively from the canonical public base URL.
    ///
    /// Root deployment:
    ///
    ///   ""
    ///
    /// Subdirectory deployment:
    ///
    ///   "/arata"
    base_path: String,
    /// Navigation entries in display order.
    menu: List(MenuItem),
    /// Social entries in display order.
    ///
    /// The managed RSS entry is present only when `rss_enabled` is `True`.
    socials: List(Social),
    /// Optional resolved navigation logo path.
    ///
    /// When `None`, the site title is rendered as a text link.
    logo: Option(String),
    /// Optional resolved favicon path.
    favicon: Option(String),
    /// Whether RSS and Atom feeds are enabled.
    rss_enabled: Bool,
    /// Body, heading, and code font-family declarations.
    fonts: Fonts,
    /// Whether the in-page search interface and keyboard shortcut are enabled.
    search_enabled: Bool,
    /// Whether the navigation bar remains pinned while scrolling.
    navbar_fixed: Bool,
    /// Public analytics provider configuration used by the SPA.
    analytics: Analytics,
    /// Whether MathJax rendering is enabled.
    mathjax_enabled: Bool,
    /// Resolved public MathJax runtime asset URL.
    mathjax_cdn_url: String,
    /// Whether Mermaid rendering is enabled.
    mermaid_enabled: Bool,
    /// Resolved public Mermaid ESM runtime asset URL.
    mermaid_cdn_url: String,
    /// Whether runtime syntax highlighting is enabled.
    syntax_highlight_enabled: Bool,
    /// Resolved public syntax-highlighting runtime asset URL.
    syntax_highlight_cdn_url: String,
    /// Whether the post sidebar is rendered.
    sidebar_enabled: Bool,
    /// Whether floating post controls are rendered.
    floating_buttons_enabled: Bool,
    /// Whether the homepage aratafetch summary is rendered.
    aratafetch_enabled: Bool,
    /// Optional value displayed in the aratafetch `maintained` row.
    aratafetch_maintained_for: Option(String),
    /// Whether Markdown body images use the built-in lightbox.
    lightbox_enabled: Bool,
    /// Whether the homepage latest-posts section is rendered.
    latest_posts_enabled: Bool,
    /// Maximum number of posts rendered in the latest-posts section.
    latest_posts_count: Int,
  )
}

/// Return built-in site metadata.
///
/// This function preserves the legacy API for tests and existing callers. It
/// does not read `content/arata.toml`.
///
/// Production build code should use the metadata created by
/// `config/resolve.resolve` so build output and runtime configuration originate
/// from the same resolved input.
pub fn site_meta() -> SiteMeta {
  let base_url =
    defaults.base_url()
    |> config_url.canonical_base_url

  SiteMeta(
    base_url: base_url,
    title: defaults.title(),
    description: defaults.description(),
    analytics: defaults.analytics(),
    comments: defaults.comments(),
    fediverse_creator: defaults.fediverse_creator(),
    rss_enabled: defaults.rss_enabled(),
  )
}

/// Return Arata's fully resolved built-in application configuration.
///
/// This function preserves the legacy API and current behavior when no user
/// configuration has been loaded. It does not read `content/arata.toml`.
///
/// Production build code must not call this function independently in multiple
/// pipeline stages. Configuration should be loaded and resolved once, then
/// passed explicitly to downstream consumers.
pub fn default() -> Config {
  let metadata = site_meta()
  let base_path = config_url.base_path_from_url(metadata.base_url)
  let rss_enabled = metadata.rss_enabled

  Config(
    title: metadata.title,
    description: metadata.description,
    base_path: base_path,
    menu: default_menu(base_path),
    socials: default_socials(base_path, rss_enabled),
    logo: resolve_optional_site_url(base_path, defaults.logo()),
    favicon: resolve_optional_site_url(base_path, defaults.favicon()),
    rss_enabled: rss_enabled,
    fonts: Fonts(
      text: defaults.text_font(),
      header: defaults.header_font(),
      code: defaults.code_font(),
    ),
    search_enabled: defaults.search_enabled(),
    navbar_fixed: defaults.navbar_fixed(),
    analytics: metadata.analytics,
    mathjax_enabled: defaults.mathjax_enabled(),
    mathjax_cdn_url: config_url.resolve_site_url(
      base_path,
      defaults.mathjax_url(),
    ),
    mermaid_enabled: defaults.mermaid_enabled(),
    mermaid_cdn_url: config_url.resolve_site_url(
      base_path,
      defaults.mermaid_url(),
    ),
    syntax_highlight_enabled: defaults.syntax_highlight_enabled(),
    syntax_highlight_cdn_url: config_url.resolve_site_url(
      base_path,
      defaults.syntax_highlight_url(),
    ),
    sidebar_enabled: defaults.sidebar_enabled(),
    floating_buttons_enabled: defaults.floating_buttons_enabled(),
    aratafetch_enabled: defaults.aratafetch_enabled(),
    aratafetch_maintained_for: defaults.aratafetch_maintained_for(),
    lightbox_enabled: defaults.lightbox_enabled(),
    latest_posts_enabled: defaults.latest_posts_enabled(),
    latest_posts_count: defaults.latest_posts_count(),
  )
}

/// Canonicalize the public deployed site URL.
///
/// This compatibility wrapper delegates to `config/url`.
pub fn canonical_base_url(url: String) -> String {
  config_url.canonical_base_url(url)
}

/// Derive the deployment base path from a public site URL.
///
/// This compatibility wrapper delegates to `config/url`.
pub fn base_path_from_url(url: String) -> String {
  config_url.base_path_from_url(url)
}

/// Normalize a deployment base path.
///
/// This compatibility wrapper delegates to `config/url`.
pub fn normalize_base_path(path: String) -> String {
  config_url.normalize_base_path(path)
}

/// Prefix a site-local path with a deployment base path.
///
/// This compatibility wrapper delegates to `config/url`.
///
/// Callers must ensure that a path receives its deployment prefix exactly
/// once. For configurable URLs that may also be external, prefer
/// `resolve_site_url`.
pub fn with_base_path(base_path: String, path: String) -> String {
  config_url.with_base_path(base_path, path)
}

/// Resolve a configurable URL against the deployment base path.
///
/// External and browser-special URLs are returned unchanged. Site-local paths
/// receive the deployment prefix.
pub fn resolve_site_url(base_path: String, url: String) -> String {
  config_url.resolve_site_url(base_path, url)
}

/// Return whether a URL is external or browser-special and therefore must not
/// receive Arata's deployment base path.
pub fn is_external_or_special_url(url: String) -> Bool {
  config_url.is_external_or_special_url(url)
}

/// Return whether a URL is an absolute HTTP or HTTPS URL.
pub fn is_http_url(url: String) -> Bool {
  config_url.is_http_url(url)
}

/// Return whether a non-empty configurable URL is site-local.
pub fn is_site_local_url(url: String) -> Bool {
  config_url.is_site_local_url(url)
}

fn default_menu(base_path: String) -> List(MenuItem) {
  defaults.menu()
  |> list.map(fn(item) {
    let #(name, configured_url) = item

    MenuItem(
      name: name,
      url: config_url.resolve_site_url(base_path, configured_url),
    )
  })
}

fn default_socials(base_path: String, rss_enabled: Bool) -> List(Social) {
  let managed_rss = case rss_enabled {
    False -> []

    True -> {
      let #(name, configured_url, icon) = defaults.rss_social()

      [
        Social(
          name: name,
          url: config_url.resolve_site_url(base_path, configured_url),
          icon: icon,
        ),
      ]
    }
  }

  let configured_socials =
    defaults.socials()
    |> list.map(fn(item) {
      let #(name, configured_url, icon) = item

      Social(
        name: name,
        url: config_url.resolve_site_url(base_path, configured_url),
        icon: icon,
      )
    })

  list.append(managed_rss, configured_socials)
}

fn resolve_optional_site_url(
  base_path: String,
  configured_url: Option(String),
) -> Option(String) {
  case configured_url {
    Some(url) -> Some(config_url.resolve_site_url(base_path, url))

    None -> None
  }
}
