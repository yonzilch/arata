//// Decode `content/arata.toml` into Arata's raw configuration model.
////
//// This module performs two operations:
////
////   1. Parse TOML source text with `tom`.
////   2. Decode the parsed TOML tree into `config/raw.RawConfig`.
////
//// Decoding preserves missing fields as `None`. Defaults, path normalization,
//// provider construction, and semantic validation belong to later stages.
////
//// Collection presence is preserved explicitly:
////
////   missing `menu` / `socials` -> None
////   `menu = []` / `socials = []` -> Some([])
////   `[[menu]]` / `[[socials]]` -> Some(items)
////
//// Unknown keys and type mismatches are reported as structured configuration
//// errors. Independent decoding errors are accumulated where practical.
////
//// This module does not:
////
////   - read files;
////   - apply built-in defaults;
////   - derive deployment paths;
////   - validate cross-field invariants;
////   - verify referenced assets;
////   - write build output.

import config/error.{type ConfigError}
import config/loader.{type ConfigSource}
import config/raw.{
  type RawAnalytics, type RawAratafetch, type RawAssets, type RawComments,
  type RawConfig, type RawFeatures, type RawFonts, type RawLatestPosts,
  type RawMenuItem, type RawSite, type RawSocial, RawAnalytics, RawAratafetch,
  RawAssets, RawComments, RawConfig, RawFeatures, RawFonts, RawLatestPosts,
  RawMenuItem, RawSite, RawSocial,
}
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import tom.{type Toml}

/// A decoded optional value together with diagnostics produced while reading
/// that value.
///
/// Missing optional values produce:
///
///   Field(value: None, errors: [])
///
/// Present but invalid values produce:
///
///   Field(value: None, errors: [error])
type Field(a) {
  Field(value: Option(a), errors: List(ConfigError))
}

/// Parse and decode a loaded configuration source.
pub fn decode(source: ConfigSource) -> Result(RawConfig, List(ConfigError)) {
  decode_text(loader.path(source), loader.contents(source))
}

/// Parse and decode TOML text associated with a specific source path.
///
/// This entry point is useful for tests and callers that already own the source
/// text.
pub fn decode_text(
  source_path: String,
  source: String,
) -> Result(RawConfig, List(ConfigError)) {
  case tom.parse(source) {
    Error(parse_error) ->
      Error([
        error.parse(
          source_path,
          "could not parse TOML configuration: " <> string.inspect(parse_error),
          None,
        ),
      ])

    Ok(document) -> decode_root(source_path, document)
  }
}

fn decode_root(
  source_path: String,
  root: Dict(String, Toml),
) -> Result(RawConfig, List(ConfigError)) {
  let unknown_errors =
    unknown_key_errors(source_path, None, root, [
      "site",
      "menu",
      "socials",
      "features",
      "latest_posts",
      "aratafetch",
      "fonts",
      "assets",
      "analytics",
      "comments",
    ])

  let site = optional_section(source_path, root, "site", decode_site)

  let menu =
    optional_array_of_tables(source_path, root, "menu", decode_menu_item)

  let socials =
    optional_array_of_tables(source_path, root, "socials", decode_social)

  let features =
    optional_section(source_path, root, "features", decode_features)

  let latest_posts =
    optional_section(source_path, root, "latest_posts", decode_latest_posts)

  let aratafetch =
    optional_section(source_path, root, "aratafetch", decode_aratafetch)

  let fonts = optional_section(source_path, root, "fonts", decode_fonts)

  let assets = optional_section(source_path, root, "assets", decode_assets)

  let analytics =
    optional_section(source_path, root, "analytics", decode_analytics)

  let comments =
    optional_section(source_path, root, "comments", decode_comments)

  let errors =
    unknown_errors
    |> append_field_errors(site)
    |> append_field_errors(menu)
    |> append_field_errors(socials)
    |> append_field_errors(features)
    |> append_field_errors(latest_posts)
    |> append_field_errors(aratafetch)
    |> append_field_errors(fonts)
    |> append_field_errors(assets)
    |> append_field_errors(analytics)
    |> append_field_errors(comments)

  case errors {
    [] ->
      Ok(RawConfig(
        site: site.value,
        menu: menu.value,
        socials: socials.value,
        features: features.value,
        latest_posts: latest_posts.value,
        aratafetch: aratafetch.value,
        fonts: fonts.value,
        assets: assets.value,
        analytics: analytics.value,
        comments: comments.value,
      ))

    _ -> Error(errors)
  }
}

fn decode_site(
  source_path: String,
  table: Dict(String, Toml),
) -> Field(RawSite) {
  let section = "site"

  let base_url = optional_string(source_path, section, table, "base_url")

  let title = optional_string(source_path, section, table, "title")

  let description = optional_string(source_path, section, table, "description")

  let logo = optional_string(source_path, section, table, "logo")

  let favicon = optional_string(source_path, section, table, "favicon")

  let fediverse_creator =
    optional_string(source_path, section, table, "fediverse_creator")

  let errors =
    unknown_key_errors(source_path, Some(section), table, [
      "base_url",
      "title",
      "description",
      "logo",
      "favicon",
      "fediverse_creator",
    ])
    |> append_field_errors(base_url)
    |> append_field_errors(title)
    |> append_field_errors(description)
    |> append_field_errors(logo)
    |> append_field_errors(favicon)
    |> append_field_errors(fediverse_creator)

  Field(
    value: Some(RawSite(
      base_url: base_url.value,
      title: title.value,
      description: description.value,
      logo: logo.value,
      favicon: favicon.value,
      fediverse_creator: fediverse_creator.value,
    )),
    errors: errors,
  )
}

fn decode_menu_item(
  source_path: String,
  section: String,
  table: Dict(String, Toml),
) -> Field(RawMenuItem) {
  let name = optional_string(source_path, section, table, "name")

  let url = optional_string(source_path, section, table, "url")

  let errors =
    unknown_key_errors(source_path, Some(section), table, ["name", "url"])
    |> append_field_errors(name)
    |> append_field_errors(url)

  Field(
    value: Some(RawMenuItem(name: name.value, url: url.value)),
    errors: errors,
  )
}

fn decode_social(
  source_path: String,
  section: String,
  table: Dict(String, Toml),
) -> Field(RawSocial) {
  let name = optional_string(source_path, section, table, "name")

  let url = optional_string(source_path, section, table, "url")

  let icon = optional_string(source_path, section, table, "icon")

  let errors =
    unknown_key_errors(source_path, Some(section), table, [
      "name",
      "url",
      "icon",
    ])
    |> append_field_errors(name)
    |> append_field_errors(url)
    |> append_field_errors(icon)

  Field(
    value: Some(RawSocial(name: name.value, url: url.value, icon: icon.value)),
    errors: errors,
  )
}

fn decode_features(
  source_path: String,
  table: Dict(String, Toml),
) -> Field(RawFeatures) {
  let section = "features"

  let rss = optional_bool(source_path, section, table, "rss")

  let search = optional_bool(source_path, section, table, "search")

  let navbar_fixed = optional_bool(source_path, section, table, "navbar_fixed")

  let mathjax = optional_bool(source_path, section, table, "mathjax")

  let mermaid = optional_bool(source_path, section, table, "mermaid")

  let syntax_highlight =
    optional_bool(source_path, section, table, "syntax_highlight")

  let sidebar = optional_bool(source_path, section, table, "sidebar")

  let floating_buttons =
    optional_bool(source_path, section, table, "floating_buttons")

  let aratafetch = optional_bool(source_path, section, table, "aratafetch")

  let lightbox = optional_bool(source_path, section, table, "lightbox")

  let latest_posts = optional_bool(source_path, section, table, "latest_posts")

  let errors =
    unknown_key_errors(source_path, Some(section), table, [
      "rss",
      "search",
      "navbar_fixed",
      "mathjax",
      "mermaid",
      "syntax_highlight",
      "sidebar",
      "floating_buttons",
      "aratafetch",
      "lightbox",
      "latest_posts",
    ])
    |> append_field_errors(rss)
    |> append_field_errors(search)
    |> append_field_errors(navbar_fixed)
    |> append_field_errors(mathjax)
    |> append_field_errors(mermaid)
    |> append_field_errors(syntax_highlight)
    |> append_field_errors(sidebar)
    |> append_field_errors(floating_buttons)
    |> append_field_errors(aratafetch)
    |> append_field_errors(lightbox)
    |> append_field_errors(latest_posts)

  Field(
    value: Some(RawFeatures(
      rss: rss.value,
      search: search.value,
      navbar_fixed: navbar_fixed.value,
      mathjax: mathjax.value,
      mermaid: mermaid.value,
      syntax_highlight: syntax_highlight.value,
      sidebar: sidebar.value,
      floating_buttons: floating_buttons.value,
      aratafetch: aratafetch.value,
      lightbox: lightbox.value,
      latest_posts: latest_posts.value,
    )),
    errors: errors,
  )
}

fn decode_latest_posts(
  source_path: String,
  table: Dict(String, Toml),
) -> Field(RawLatestPosts) {
  let section = "latest_posts"

  let count = optional_int(source_path, section, table, "count")

  let errors =
    unknown_key_errors(source_path, Some(section), table, ["count"])
    |> append_field_errors(count)

  Field(value: Some(RawLatestPosts(count: count.value)), errors: errors)
}

fn decode_aratafetch(
  source_path: String,
  table: Dict(String, Toml),
) -> Field(RawAratafetch) {
  let section = "aratafetch"

  let maintained_for =
    optional_string(source_path, section, table, "maintained_for")

  let errors =
    unknown_key_errors(source_path, Some(section), table, ["maintained_for"])
    |> append_field_errors(maintained_for)

  Field(
    value: Some(RawAratafetch(maintained_for: maintained_for.value)),
    errors: errors,
  )
}

fn decode_fonts(
  source_path: String,
  table: Dict(String, Toml),
) -> Field(RawFonts) {
  let section = "fonts"

  let text = optional_string(source_path, section, table, "text")

  let header = optional_string(source_path, section, table, "header")

  let code = optional_string(source_path, section, table, "code")

  let errors =
    unknown_key_errors(source_path, Some(section), table, [
      "text",
      "header",
      "code",
    ])
    |> append_field_errors(text)
    |> append_field_errors(header)
    |> append_field_errors(code)

  Field(
    value: Some(RawFonts(
      text: text.value,
      header: header.value,
      code: code.value,
    )),
    errors: errors,
  )
}

fn decode_assets(
  source_path: String,
  table: Dict(String, Toml),
) -> Field(RawAssets) {
  let section = "assets"

  let mathjax_url = optional_string(source_path, section, table, "mathjax_url")

  let mermaid_url = optional_string(source_path, section, table, "mermaid_url")

  let syntax_highlight_url =
    optional_string(source_path, section, table, "syntax_highlight_url")

  let errors =
    unknown_key_errors(source_path, Some(section), table, [
      "mathjax_url",
      "mermaid_url",
      "syntax_highlight_url",
    ])
    |> append_field_errors(mathjax_url)
    |> append_field_errors(mermaid_url)
    |> append_field_errors(syntax_highlight_url)

  Field(
    value: Some(RawAssets(
      mathjax_url: mathjax_url.value,
      mermaid_url: mermaid_url.value,
      syntax_highlight_url: syntax_highlight_url.value,
    )),
    errors: errors,
  )
}

fn decode_analytics(
  source_path: String,
  table: Dict(String, Toml),
) -> Field(RawAnalytics) {
  let section = "analytics"

  let provider = optional_string(source_path, section, table, "provider")

  let data_goatcounter =
    optional_string(source_path, section, table, "data_goatcounter")

  let website_id = optional_string(source_path, section, table, "website_id")

  let data_entity = optional_string(source_path, section, table, "data_entity")

  let src = optional_string(source_path, section, table, "src")

  let errors =
    unknown_key_errors(source_path, Some(section), table, [
      "provider",
      "data_goatcounter",
      "website_id",
      "data_entity",
      "src",
    ])
    |> append_field_errors(provider)
    |> append_field_errors(data_goatcounter)
    |> append_field_errors(website_id)
    |> append_field_errors(data_entity)
    |> append_field_errors(src)

  Field(
    value: Some(RawAnalytics(
      provider: provider.value,
      data_goatcounter: data_goatcounter.value,
      website_id: website_id.value,
      data_entity: data_entity.value,
      src: src.value,
    )),
    errors: errors,
  )
}

fn decode_comments(
  source_path: String,
  table: Dict(String, Toml),
) -> Field(RawComments) {
  let section = "comments"

  let provider = optional_string(source_path, section, table, "provider")

  let repo = optional_string(source_path, section, table, "repo")

  let repo_id = optional_string(source_path, section, table, "repo_id")

  let category = optional_string(source_path, section, table, "category")

  let category_id = optional_string(source_path, section, table, "category_id")

  let mapping = optional_string(source_path, section, table, "mapping")

  let strict = optional_bool(source_path, section, table, "strict")

  let reactions_enabled =
    optional_bool(source_path, section, table, "reactions_enabled")

  let emit_metadata =
    optional_bool(source_path, section, table, "emit_metadata")

  let input_position =
    optional_string(source_path, section, table, "input_position")

  let theme = optional_string(source_path, section, table, "theme")

  let lang = optional_string(source_path, section, table, "lang")

  let loading = optional_string(source_path, section, table, "loading")

  let issue_term = optional_string(source_path, section, table, "issue_term")

  let src = optional_string(source_path, section, table, "src")

  let errors =
    unknown_key_errors(source_path, Some(section), table, [
      "provider",
      "repo",
      "repo_id",
      "category",
      "category_id",
      "mapping",
      "strict",
      "reactions_enabled",
      "emit_metadata",
      "input_position",
      "theme",
      "lang",
      "loading",
      "issue_term",
      "src",
    ])
    |> append_field_errors(provider)
    |> append_field_errors(repo)
    |> append_field_errors(repo_id)
    |> append_field_errors(category)
    |> append_field_errors(category_id)
    |> append_field_errors(mapping)
    |> append_field_errors(strict)
    |> append_field_errors(reactions_enabled)
    |> append_field_errors(emit_metadata)
    |> append_field_errors(input_position)
    |> append_field_errors(theme)
    |> append_field_errors(lang)
    |> append_field_errors(loading)
    |> append_field_errors(issue_term)
    |> append_field_errors(src)

  Field(
    value: Some(RawComments(
      provider: provider.value,
      repo: repo.value,
      repo_id: repo_id.value,
      category: category.value,
      category_id: category_id.value,
      mapping: mapping.value,
      strict: strict.value,
      reactions_enabled: reactions_enabled.value,
      emit_metadata: emit_metadata.value,
      input_position: input_position.value,
      theme: theme.value,
      lang: lang.value,
      loading: loading.value,
      issue_term: issue_term.value,
      src: src.value,
    )),
    errors: errors,
  )
}

fn optional_section(
  source_path: String,
  root: Dict(String, Toml),
  key: String,
  decoder: fn(String, Dict(String, Toml)) -> Field(a),
) -> Field(a) {
  case dict.get(root, key) {
    Error(_) -> Field(value: None, errors: [])

    Ok(tom.Table(table)) -> decoder(source_path, table)

    Ok(tom.InlineTable(table)) -> decoder(source_path, table)

    Ok(value) ->
      Field(value: None, errors: [
        error.decode(
          source_path,
          Some(key),
          None,
          "a TOML table",
          toml_type_name(value),
          "configuration section must be a TOML table",
        ),
      ])
  }
}

/// Decode an optional repeated-table collection.
///
/// The decoder distinguishes all three configuration states:
///
///   missing key
///     -> None
///
///   key = []
///     -> Some([])
///
///   [[key]]
///     -> Some(items)
///
/// Non-empty ordinary arrays remain invalid. Collection entries must use TOML
/// repeated-table syntax so each item has a named field structure.
fn optional_array_of_tables(
  source_path: String,
  root: Dict(String, Toml),
  key: String,
  decoder: fn(String, String, Dict(String, Toml)) -> Field(a),
) -> Field(List(a)) {
  case dict.get(root, key) {
    Error(_) -> Field(value: None, errors: [])

    Ok(tom.ArrayOfTables(tables)) ->
      decode_array_tables(source_path, key, tables, decoder, 0, [], [])

    // TOML parsers represent `menu = []` and `socials = []` as an ordinary
    // empty array rather than an array of tables. Accept this exact form so an
    // explicit empty collection can replace Arata's built-in defaults.
    Ok(tom.Array([])) -> Field(value: Some([]), errors: [])

    Ok(tom.Array(_)) ->
      Field(value: None, errors: [
        error.decode(
          source_path,
          Some(key),
          None,
          "an empty array or an array of TOML tables",
          "non-empty array",
          "non-empty configuration collections must use repeated TOML tables",
        ),
      ])

    Ok(value) ->
      Field(value: None, errors: [
        error.decode(
          source_path,
          Some(key),
          None,
          "an empty array or an array of TOML tables",
          toml_type_name(value),
          "configuration collection must use repeated TOML tables",
        ),
      ])
  }
}

fn decode_array_tables(
  source_path: String,
  section: String,
  tables: List(Dict(String, Toml)),
  decoder: fn(String, String, Dict(String, Toml)) -> Field(a),
  index: Int,
  values: List(a),
  errors: List(ConfigError),
) -> Field(List(a)) {
  case tables {
    [] -> Field(value: Some(list.reverse(values)), errors: errors)

    [table, ..rest] -> {
      let item_section = section <> "[" <> int.to_string(index) <> "]"

      let decoded = decoder(source_path, item_section, table)

      let next_values = case decoded.value {
        Some(value) -> [value, ..values]

        None -> values
      }

      decode_array_tables(
        source_path,
        section,
        rest,
        decoder,
        index + 1,
        next_values,
        list.append(errors, decoded.errors),
      )
    }
  }
}

fn optional_string(
  source_path: String,
  section: String,
  table: Dict(String, Toml),
  key: String,
) -> Field(String) {
  case dict.get(table, key) {
    Error(_) -> Field(value: None, errors: [])

    Ok(tom.String(value)) -> Field(value: Some(value), errors: [])

    Ok(value) -> wrong_type_field(source_path, section, key, "a string", value)
  }
}

fn optional_bool(
  source_path: String,
  section: String,
  table: Dict(String, Toml),
  key: String,
) -> Field(Bool) {
  case dict.get(table, key) {
    Error(_) -> Field(value: None, errors: [])

    Ok(tom.Bool(value)) -> Field(value: Some(value), errors: [])

    Ok(value) -> wrong_type_field(source_path, section, key, "a boolean", value)
  }
}

fn optional_int(
  source_path: String,
  section: String,
  table: Dict(String, Toml),
  key: String,
) -> Field(Int) {
  case dict.get(table, key) {
    Error(_) -> Field(value: None, errors: [])

    Ok(tom.Int(value)) -> Field(value: Some(value), errors: [])

    Ok(value) ->
      wrong_type_field(source_path, section, key, "an integer", value)
  }
}

fn wrong_type_field(
  source_path: String,
  section: String,
  key: String,
  expected: String,
  value: Toml,
) -> Field(a) {
  Field(value: None, errors: [
    error.decode(
      source_path,
      Some(section),
      Some(key),
      expected,
      toml_type_name(value),
      "configuration value has the wrong TOML type",
    ),
  ])
}

fn unknown_key_errors(
  source_path: String,
  section: Option(String),
  table: Dict(String, Toml),
  allowed: List(String),
) -> List(ConfigError) {
  table
  |> dict.keys
  |> list.filter_map(fn(key) {
    case list.contains(allowed, key) {
      True -> Error(Nil)

      False ->
        Ok(error.unknown_key(
          source_path,
          section,
          key,
          "unknown configuration key",
        ))
    }
  })
}

fn append_field_errors(
  errors: List(ConfigError),
  field: Field(a),
) -> List(ConfigError) {
  list.append(errors, field.errors)
}

fn toml_type_name(value: Toml) -> String {
  case value {
    tom.Int(_) -> "integer"

    tom.Float(_) -> "float"

    tom.Infinity(_) -> "infinity"

    tom.Nan(_) -> "NaN"

    tom.Bool(_) -> "boolean"

    tom.String(_) -> "string"

    tom.Date(_) -> "date"

    tom.Time(_) -> "time"

    tom.DateTime(_, _, _) -> "date-time"

    tom.Array(_) -> "array"

    tom.ArrayOfTables(_) -> "array of tables"

    tom.Table(_) -> "table"

    tom.InlineTable(_) -> "inline table"
  }
}
