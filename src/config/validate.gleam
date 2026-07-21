//// Semantic validation for resolved Arata configuration.
////
//// This module validates configuration after defaults have been applied and
//// deployment paths have been resolved.
////
//// Validation is intentionally separate from TOML decoding:
////
////   - decoding verifies TOML structure and value types;
////   - resolution applies defaults and derives normalized values;
////   - validation verifies cross-field and semantic invariants.
////
//// All independent validation errors are collected so users can correct
//// multiple configuration problems in one pass.
////
//// This module does not:
////
////   - read or parse `content/arata.toml`;
////   - detect unknown TOML keys;
////   - apply defaults;
////   - mutate or repair invalid configuration;
////   - write build output;
////   - verify local asset existence on disk.
////
//// Local asset existence requires file-system access and should be implemented
//// as a separate validation stage before the build pipeline writes `dist/`.

import config
import config/error.{type ConfigError}
import config/resolve.{type ResolvedConfig}
import config/url
import data/site.{
  type Analytics, type CommentsConfig, AnalyticsDisabled, CommentsDisabled,
  Giscus, GoatCounter, Liwan, Umami, Utterances,
}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string

/// Default source path used in validation diagnostics.
pub const default_source_path = "content/arata.toml"

/// Validate resolved configuration using Arata's canonical configuration path.
///
/// Successful validation returns the original resolved value unchanged so this
/// function can be inserted directly into a configuration pipeline.
pub fn validate(
  resolved: ResolvedConfig,
) -> Result(ResolvedConfig, List(ConfigError)) {
  validate_from(default_source_path, resolved)
}

/// Validate resolved configuration loaded from a specific source path.
///
/// The returned errors preserve the supplied path so tests and future explicit
/// configuration-path support can identify the correct source file.
pub fn validate_from(
  source_path: String,
  resolved: ResolvedConfig,
) -> Result(ResolvedConfig, List(ConfigError)) {
  let application = resolve.runtime_config(resolved)
  let metadata = resolve.site_meta(resolved)

  let errors =
    []
    |> append_errors(validate_base_url(source_path, metadata.base_url))
    |> append_errors(validate_site_identity(
      source_path,
      application.title,
      application.description,
    ))
    |> append_errors(validate_base_path(
      source_path,
      metadata.base_url,
      application.base_path,
    ))
    |> append_errors(validate_menu(source_path, application.menu))
    |> append_errors(validate_socials(
      source_path,
      application.socials,
      application.rss_enabled,
    ))
    |> append_errors(validate_fonts(source_path, application.fonts))
    |> append_errors(validate_feature_assets(source_path, application))
    |> append_errors(validate_latest_posts(source_path, application))
    |> append_errors(validate_analytics(source_path, application.analytics))
    |> append_errors(validate_comments(source_path, metadata.comments))
    |> append_errors(validate_shared_values(
      source_path,
      application,
      metadata.title,
      metadata.description,
      metadata.analytics,
      metadata.rss_enabled,
    ))

  case errors {
    [] -> Ok(resolved)
    _ -> Error(errors)
  }
}

fn validate_base_url(
  source_path: String,
  base_url: String,
) -> List(ConfigError) {
  let base_url = string.trim(base_url)

  case base_url {
    "" -> [
      error.validation(
        source_path,
        Some("site"),
        Some("base_url"),
        Some("an absolute HTTP or HTTPS URL"),
        Some(""),
        "site base URL must not be empty",
      ),
    ]

    _ -> {
      let errors = case url.is_http_url(base_url) {
        True -> []

        False -> [
          error.validation(
            source_path,
            Some("site"),
            Some("base_url"),
            Some("an absolute HTTP or HTTPS URL"),
            Some(base_url),
            "site base URL must use HTTP or HTTPS",
          ),
        ]
      }

      errors
      |> append_errors(validate_base_url_suffix(source_path, base_url))
      |> append_errors(validate_base_url_authority(source_path, base_url))
    }
  }
}

fn validate_base_url_suffix(
  source_path: String,
  base_url: String,
) -> List(ConfigError) {
  let query_errors = case string.contains(base_url, "?") {
    True -> [
      error.validation(
        source_path,
        Some("site"),
        Some("base_url"),
        Some("a canonical URL without a query string"),
        Some(base_url),
        "site base URL must not contain a query string",
      ),
    ]

    False -> []
  }

  let fragment_errors = case string.contains(base_url, "#") {
    True -> [
      error.validation(
        source_path,
        Some("site"),
        Some("base_url"),
        Some("a canonical URL without a fragment"),
        Some(base_url),
        "site base URL must not contain a fragment",
      ),
    ]

    False -> []
  }

  list.append(query_errors, fragment_errors)
}

fn validate_base_url_authority(
  source_path: String,
  base_url: String,
) -> List(ConfigError) {
  case string.split_once(base_url, "://") {
    Error(_) -> []

    Ok(#(_scheme, authority_and_path)) -> {
      let authority = case string.split_once(authority_and_path, "/") {
        Ok(#(authority, _path)) -> authority
        Error(_) -> authority_and_path
      }

      case string.trim(authority) {
        "" -> [
          error.validation(
            source_path,
            Some("site"),
            Some("base_url"),
            Some("an absolute URL with a host"),
            Some(base_url),
            "site base URL must include a host",
          ),
        ]

        _ -> []
      }
    }
  }
}

fn validate_site_identity(
  source_path: String,
  title: String,
  _description: String,
) -> List(ConfigError) {
  case string.trim(title) {
    "" -> [
      error.validation(
        source_path,
        Some("site"),
        Some("title"),
        Some("a non-empty string"),
        Some(""),
        "site title must not be empty",
      ),
    ]

    _ -> []
  }
}

fn validate_base_path(
  source_path: String,
  base_url: String,
  base_path: String,
) -> List(ConfigError) {
  let expected = url.base_path_from_url(base_url)

  case base_path == expected {
    True -> []

    False -> [
      error.validation(
        source_path,
        Some("site"),
        Some("base_url"),
        Some("a URL whose derived base path is " <> inspect_path(expected)),
        Some(base_url <> " produced " <> inspect_path(base_path)),
        "resolved base path does not match the canonical base URL",
      ),
    ]
  }
}

fn validate_menu(
  source_path: String,
  items: List(config.MenuItem),
) -> List(ConfigError) {
  validate_menu_items(source_path, items, 0)
}

fn validate_menu_items(
  source_path: String,
  items: List(config.MenuItem),
  index: Int,
) -> List(ConfigError) {
  case items {
    [] -> []

    [item, ..rest] -> {
      let section = "menu[" <> int.to_string(index) <> "]"

      let current_errors =
        []
        |> append_errors(validate_required_string(
          source_path,
          section,
          "name",
          item.name,
        ))
        |> append_errors(validate_navigation_url(
          source_path,
          section,
          "url",
          item.url,
        ))

      list.append(
        current_errors,
        validate_menu_items(source_path, rest, index + 1),
      )
    }
  }
}

fn validate_socials(
  source_path: String,
  socials: List(config.Social),
  rss_enabled: Bool,
) -> List(ConfigError) {
  let entry_errors = validate_social_entries(source_path, socials, 0)

  let rss_errors =
    validate_managed_rss_social(source_path, socials, rss_enabled)

  list.append(entry_errors, rss_errors)
}

fn validate_social_entries(
  source_path: String,
  socials: List(config.Social),
  index: Int,
) -> List(ConfigError) {
  case socials {
    [] -> []

    [social, ..rest] -> {
      let section = "socials[" <> int.to_string(index) <> "]"

      let current_errors =
        []
        |> append_errors(validate_required_string(
          source_path,
          section,
          "name",
          social.name,
        ))
        |> append_errors(validate_navigation_url(
          source_path,
          section,
          "url",
          social.url,
        ))
        |> append_errors(validate_social_icon(source_path, section, social.icon))

      list.append(
        current_errors,
        validate_social_entries(source_path, rest, index + 1),
      )
    }
  }
}

fn validate_social_icon(
  source_path: String,
  section: String,
  icon: String,
) -> List(ConfigError) {
  let icon = string.trim(icon)

  case icon {
    "" -> [
      error.validation(
        source_path,
        Some(section),
        Some("icon"),
        Some("an SVG filename without an extension"),
        Some(""),
        "social icon must not be empty",
      ),
    ]

    _ -> {
      let separator_errors = case
        string.contains(icon, "/") || string.contains(icon, "\\")
      {
        True -> [
          error.validation(
            source_path,
            Some(section),
            Some("icon"),
            Some("a filename under static/icons/social"),
            Some(icon),
            "social icon must not contain path separators",
          ),
        ]

        False -> []
      }

      let extension_errors = case
        string.ends_with(string.lowercase(icon), ".svg")
      {
        True -> [
          error.validation(
            source_path,
            Some(section),
            Some("icon"),
            Some("an SVG filename without the .svg extension"),
            Some(icon),
            "social icon must not include a file extension",
          ),
        ]

        False -> []
      }

      list.append(separator_errors, extension_errors)
    }
  }
}

fn validate_managed_rss_social(
  source_path: String,
  socials: List(config.Social),
  rss_enabled: Bool,
) -> List(ConfigError) {
  let count = count_rss_socials(socials)

  case rss_enabled, count {
    True, 1 -> []

    True, 0 -> [
      error.validation(
        source_path,
        Some("socials"),
        Some("rss"),
        Some("exactly one managed RSS social"),
        Some("none"),
        "RSS is enabled but the managed RSS social is missing",
      ),
    ]

    True, _ -> [
      error.validation(
        source_path,
        Some("socials"),
        Some("rss"),
        Some("exactly one managed RSS social"),
        Some(int.to_string(count)),
        "RSS is enabled but multiple RSS socials are present",
      ),
    ]

    False, 0 -> []

    False, _ -> [
      error.validation(
        source_path,
        Some("socials"),
        Some("rss"),
        Some("no RSS social when RSS is disabled"),
        Some(int.to_string(count)),
        "RSS is disabled but an RSS social is still present",
      ),
    ]
  }
}

fn count_rss_socials(socials: List(config.Social)) -> Int {
  case socials {
    [] -> 0

    [social, ..rest] -> {
      let current = case string.lowercase(string.trim(social.icon)) == "rss" {
        True -> 1
        False -> 0
      }

      current + count_rss_socials(rest)
    }
  }
}

fn validate_fonts(
  source_path: String,
  fonts: config.Fonts,
) -> List(ConfigError) {
  []
  |> append_errors(validate_required_string(
    source_path,
    "fonts",
    "text",
    fonts.text,
  ))
  |> append_errors(validate_required_string(
    source_path,
    "fonts",
    "header",
    fonts.header,
  ))
  |> append_errors(validate_required_string(
    source_path,
    "fonts",
    "code",
    fonts.code,
  ))
}

fn validate_feature_assets(
  source_path: String,
  application: config.Config,
) -> List(ConfigError) {
  []
  |> append_errors(validate_feature_asset(
    source_path,
    "features.mathjax",
    "assets",
    "mathjax_url",
    application.mathjax_enabled,
    application.mathjax_cdn_url,
  ))
  |> append_errors(validate_feature_asset(
    source_path,
    "features.mermaid",
    "assets",
    "mermaid_url",
    application.mermaid_enabled,
    application.mermaid_cdn_url,
  ))
  |> append_errors(validate_feature_asset(
    source_path,
    "features.syntax_highlight",
    "assets",
    "syntax_highlight_url",
    application.syntax_highlight_enabled,
    application.syntax_highlight_cdn_url,
  ))
}

fn validate_feature_asset(
  source_path: String,
  feature_path: String,
  section: String,
  key: String,
  enabled: Bool,
  asset_url: String,
) -> List(ConfigError) {
  case enabled {
    False -> []

    True -> {
      let asset_url = string.trim(asset_url)

      case asset_url {
        "" -> [
          error.validation(
            source_path,
            Some(section),
            Some(key),
            Some("an HTTP, HTTPS, protocol-relative, or site-local asset URL"),
            Some(""),
            feature_path <> " is enabled but its runtime asset URL is empty",
          ),
        ]

        _ -> validate_runtime_asset_url(source_path, section, key, asset_url)
      }
    }
  }
}

fn validate_runtime_asset_url(
  source_path: String,
  section: String,
  key: String,
  asset_url: String,
) -> List(ConfigError) {
  let normalized = string.lowercase(string.trim(asset_url))

  case
    string.starts_with(normalized, "https://")
    || string.starts_with(normalized, "http://")
    || string.starts_with(normalized, "//")
    || string.starts_with(normalized, "/")
  {
    True -> []

    False -> [
      error.validation(
        source_path,
        Some(section),
        Some(key),
        Some("an HTTP, HTTPS, protocol-relative, or root-relative asset URL"),
        Some(asset_url),
        "runtime asset URL uses an unsupported URL form",
      ),
    ]
  }
}

fn validate_latest_posts(
  source_path: String,
  application: config.Config,
) -> List(ConfigError) {
  case application.latest_posts_count < 0 {
    True -> [
      error.validation(
        source_path,
        Some("latest_posts"),
        Some("count"),
        Some("a non-negative integer"),
        Some(int.to_string(application.latest_posts_count)),
        "latest posts count must not be negative",
      ),
    ]

    False -> []
  }
}

fn validate_analytics(
  source_path: String,
  analytics: Analytics,
) -> List(ConfigError) {
  case analytics {
    AnalyticsDisabled -> []

    GoatCounter(data_goatcounter:, src:) ->
      []
      |> append_errors(validate_required_string(
        source_path,
        "analytics",
        "data_goatcounter",
        data_goatcounter,
      ))
      |> append_errors(validate_provider_script(
        source_path,
        "analytics",
        "src",
        src,
      ))

    Umami(website_id:, src:) ->
      []
      |> append_errors(validate_required_string(
        source_path,
        "analytics",
        "website_id",
        website_id,
      ))
      |> append_errors(validate_provider_script(
        source_path,
        "analytics",
        "src",
        src,
      ))

    Liwan(data_entity:, src:) ->
      []
      |> append_errors(validate_required_string(
        source_path,
        "analytics",
        "data_entity",
        data_entity,
      ))
      |> append_errors(validate_provider_script(
        source_path,
        "analytics",
        "src",
        src,
      ))
  }
}

fn validate_comments(
  source_path: String,
  comments: CommentsConfig,
) -> List(ConfigError) {
  case comments {
    CommentsDisabled -> []

    Giscus(repo:, repo_id:, category:, category_id:) ->
      []
      |> append_errors(validate_repository(source_path, "comments", repo))
      |> append_errors(validate_required_string(
        source_path,
        "comments",
        "repo_id",
        repo_id,
      ))
      |> append_errors(validate_required_string(
        source_path,
        "comments",
        "category",
        category,
      ))
      |> append_errors(validate_required_string(
        source_path,
        "comments",
        "category_id",
        category_id,
      ))

    Utterances(repo:) -> validate_repository(source_path, "comments", repo)
  }
}

fn validate_repository(
  source_path: String,
  section: String,
  repo: String,
) -> List(ConfigError) {
  let required_errors =
    validate_required_string(source_path, section, "repo", repo)

  case required_errors {
    [] ->
      case string.split_once(string.trim(repo), "/") {
        Ok(#(owner, name)) ->
          case string.trim(owner), string.trim(name) {
            "", _ -> invalid_repository_error(source_path, section, repo)

            _, "" -> invalid_repository_error(source_path, section, repo)

            _, _ -> []
          }

        Error(_) -> invalid_repository_error(source_path, section, repo)
      }

    _ -> required_errors
  }
}

fn invalid_repository_error(
  source_path: String,
  section: String,
  repo: String,
) -> List(ConfigError) {
  [
    error.validation(
      source_path,
      Some(section),
      Some("repo"),
      Some("a repository in owner/name form"),
      Some(repo),
      "comments repository must use owner/name form",
    ),
  ]
}

fn validate_provider_script(
  source_path: String,
  section: String,
  key: String,
  src: String,
) -> List(ConfigError) {
  let required_errors = validate_required_string(source_path, section, key, src)

  case required_errors {
    [] -> validate_runtime_asset_url(source_path, section, key, src)

    _ -> required_errors
  }
}

fn validate_shared_values(
  source_path: String,
  application: config.Config,
  metadata_title: String,
  metadata_description: String,
  metadata_analytics: Analytics,
  metadata_rss_enabled: Bool,
) -> List(ConfigError) {
  []
  |> append_errors(validate_equal_string(
    source_path,
    "site",
    "title",
    application.title,
    metadata_title,
  ))
  |> append_errors(validate_equal_string(
    source_path,
    "site",
    "description",
    application.description,
    metadata_description,
  ))
  |> append_errors(validate_equal_bool(
    source_path,
    "features",
    "rss",
    application.rss_enabled,
    metadata_rss_enabled,
  ))
  |> append_errors(validate_equal_analytics(
    source_path,
    application.analytics,
    metadata_analytics,
  ))
}

fn validate_equal_string(
  source_path: String,
  section: String,
  key: String,
  application_value: String,
  metadata_value: String,
) -> List(ConfigError) {
  case application_value == metadata_value {
    True -> []

    False -> [
      error.validation(
        source_path,
        Some(section),
        Some(key),
        Some("identical runtime and build values"),
        Some("runtime=" <> application_value <> ", build=" <> metadata_value),
        "resolved runtime and build configuration values have drifted",
      ),
    ]
  }
}

fn validate_equal_bool(
  source_path: String,
  section: String,
  key: String,
  application_value: Bool,
  metadata_value: Bool,
) -> List(ConfigError) {
  case application_value == metadata_value {
    True -> []

    False -> [
      error.validation(
        source_path,
        Some(section),
        Some(key),
        Some("identical runtime and build values"),
        Some(
          "runtime="
          <> bool_to_string(application_value)
          <> ", build="
          <> bool_to_string(metadata_value),
        ),
        "resolved runtime and build configuration values have drifted",
      ),
    ]
  }
}

fn validate_equal_analytics(
  source_path: String,
  application_value: Analytics,
  metadata_value: Analytics,
) -> List(ConfigError) {
  case application_value == metadata_value {
    True -> []

    False -> [
      error.validation(
        source_path,
        Some("analytics"),
        Some("provider"),
        Some("identical runtime and build analytics configuration"),
        None,
        "resolved runtime and build analytics configuration has drifted",
      ),
    ]
  }
}

fn validate_required_string(
  source_path: String,
  section: String,
  key: String,
  value: String,
) -> List(ConfigError) {
  case string.trim(value) {
    "" -> [
      error.validation(
        source_path,
        Some(section),
        Some(key),
        Some("a non-empty string"),
        Some(""),
        "configuration value must not be empty",
      ),
    ]

    _ -> []
  }
}

fn validate_navigation_url(
  source_path: String,
  section: String,
  key: String,
  value: String,
) -> List(ConfigError) {
  let value = string.trim(value)

  case value {
    "" -> [
      error.validation(
        source_path,
        Some(section),
        Some(key),
        Some("a non-empty site-local or external URL"),
        Some(""),
        "navigation URL must not be empty",
      ),
    ]

    _ -> {
      let normalized = string.lowercase(value)

      case
        string.starts_with(value, "/")
        || string.starts_with(value, "#")
        || string.starts_with(normalized, "https://")
        || string.starts_with(normalized, "http://")
        || string.starts_with(normalized, "//")
        || string.starts_with(normalized, "mailto:")
        || string.starts_with(normalized, "tel:")
      {
        True -> []

        False -> [
          error.validation(
            source_path,
            Some(section),
            Some(key),
            Some(
              "a root-relative, HTTP, HTTPS, protocol-relative, fragment, mailto, or tel URL",
            ),
            Some(value),
            "navigation URL uses an unsupported URL form",
          ),
        ]
      }
    }
  }
}

fn append_errors(
  errors: List(ConfigError),
  next: List(ConfigError),
) -> List(ConfigError) {
  list.append(errors, next)
}

fn inspect_path(path: String) -> String {
  case path {
    "" -> "\"\""
    _ -> "\"" <> path <> "\""
  }
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
