//// Raw configuration types decoded from `content/arata.toml`.
////
//// These types represent user input before defaults, normalization, derived
//// values, or semantic validation are applied.
////
//// Every configurable field is optional so the resolver can distinguish:
////
////   - a missing field, which inherits the built-in default;
////   - a present scalar value, which overrides the default;
////   - a present empty string, whose meaning is decided by the resolver;
////   - a present empty list, which explicitly clears the default list.
////
//// This module must not:
////
////   - read files;
////   - parse TOML;
////   - apply built-in defaults;
////   - derive `base_path`;
////   - prefix internal URLs;
////   - validate referenced assets;
////   - construct runtime configuration.
////
//// Keeping the raw input model isolated prevents malformed or incomplete user
//// configuration from entering the build pipeline as trusted configuration.

import gleam/option.{type Option}

/// Raw representation of `content/arata.toml`.
///
/// TOML sections are optional because an empty file is valid configuration and
/// should resolve entirely from Arata's built-in defaults.
///
/// `menu` and `socials` use `Option(List(...))` deliberately:
///
///   None      -> inherit the built-in list
///   Some([])  -> explicitly clear the list
///   Some(xs)  -> replace the built-in list with `xs`
pub type RawConfig {
  RawConfig(
    site: Option(RawSite),
    menu: Option(List(RawMenuItem)),
    socials: Option(List(RawSocial)),
    features: Option(RawFeatures),
    latest_posts: Option(RawLatestPosts),
    aratafetch: Option(RawAratafetch),
    fonts: Option(RawFonts),
    assets: Option(RawAssets),
    analytics: Option(RawAnalytics),
    comments: Option(RawComments),
  )
}

/// Raw values from the `[site]` table.
///
/// `base_path` is intentionally absent. It is derived exclusively from the
/// canonical `base_url` during configuration resolution.
pub type RawSite {
  RawSite(
    base_url: Option(String),
    title: Option(String),
    description: Option(String),
    logo: Option(String),
    favicon: Option(String),
    fediverse_creator: Option(String),
  )
}

/// Raw navigation entry from a `[[menu]]` table.
///
/// Fields remain optional so decoding can preserve incomplete entries and the
/// validation stage can produce field-specific diagnostics.
pub type RawMenuItem {
  RawMenuItem(name: Option(String), url: Option(String))
}

/// Raw social entry from a `[[socials]]` table.
///
/// RSS is managed from `features.rss` and must not be defined as a regular
/// social entry. That invariant is enforced during validation.
pub type RawSocial {
  RawSocial(name: Option(String), url: Option(String), icon: Option(String))
}

/// Raw values from the `[features]` table.
pub type RawFeatures {
  RawFeatures(
    rss: Option(Bool),
    search: Option(Bool),
    navbar_fixed: Option(Bool),
    mathjax: Option(Bool),
    mermaid: Option(Bool),
    syntax_highlight: Option(Bool),
    sidebar: Option(Bool),
    floating_buttons: Option(Bool),
    aratafetch: Option(Bool),
    lightbox: Option(Bool),
    latest_posts: Option(Bool),
  )
}

/// Raw values from the `[latest_posts]` table.
pub type RawLatestPosts {
  RawLatestPosts(count: Option(Int))
}

/// Raw values from the `[aratafetch]` table.
pub type RawAratafetch {
  RawAratafetch(maintained_for: Option(String))
}

/// Raw values from the `[fonts]` table.
///
/// Values are preserved as CSS `font-family` declarations. Empty declarations
/// and other invalid values are rejected during semantic validation.
pub type RawFonts {
  RawFonts(text: Option(String), header: Option(String), code: Option(String))
}

/// Raw values from the `[assets]` table.
///
/// These values may contain absolute HTTP or HTTPS URLs or root-relative paths
/// to vendored runtime assets. Feature-dependent requirements are enforced
/// during validation.
pub type RawAssets {
  RawAssets(
    mathjax_url: Option(String),
    mermaid_url: Option(String),
    syntax_highlight_url: Option(String),
  )
}

/// Raw values from the `[analytics]` table.
///
/// `provider` selects the interpretation of the remaining fields:
///
///   disabled
///   goatcounter
///   umami
///   liwan
///
/// The raw model keeps provider-specific fields together so unsupported or
/// conflicting combinations can be reported before a trusted `Analytics`
/// value is constructed.
///
/// All analytics values are browser-visible public configuration and must not
/// contain secrets.
pub type RawAnalytics {
  RawAnalytics(
    provider: Option(String),
    /// GoatCounter script attribute containing the public counter endpoint.
    data_goatcounter: Option(String),
    /// Umami public website identifier.
    website_id: Option(String),
    /// Liwan public entity identifier.
    data_entity: Option(String),
    /// Provider script URL.
    src: Option(String),
  )
}

/// Raw values from the `[comments]` table.
///
/// `provider` selects the interpretation of the remaining fields:
///
///   disabled
///   giscus
///   utterances
///
/// Provider-specific requirements and unsupported combinations are handled by
/// the validation and resolution stages.
///
/// All comments values are browser-visible public configuration and must not
/// contain secrets.
pub type RawComments {
  RawComments(
    provider: Option(String),
    /// Repository in `owner/name` form.
    repo: Option(String),
    /// Public Giscus repository identifier.
    repo_id: Option(String),
    /// Giscus discussion category name.
    category: Option(String),
    /// Public Giscus category identifier.
    category_id: Option(String),
    /// Giscus page-to-discussion mapping strategy.
    mapping: Option(String),
    /// Whether Giscus should use strict title matching.
    strict: Option(Bool),
    /// Whether Giscus should emit reactions for the main discussion.
    reactions_enabled: Option(Bool),
    /// Whether Giscus should send discussion metadata to the parent page.
    emit_metadata: Option(Bool),
    /// Giscus comment input placement.
    input_position: Option(String),
    /// Comment widget theme.
    theme: Option(String),
    /// Comment widget language.
    lang: Option(String),
    /// Whether Giscus should load lazily.
    loading: Option(String),
    /// Utterances issue mapping strategy.
    issue_term: Option(String),
    /// Optional explicit comment widget script URL.
    src: Option(String),
  )
}
