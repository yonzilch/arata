//// Generic video shortcode.
////
//// The public contract is renderer-neutral: authors describe video content
//// and basic playback intent only. ArtPlayer-specific options, HLS provider
//// options, renderer selection, JavaScript callbacks, and plugin
//// configuration must never be added to this module.
////
//// Authors embed video with Zola-style syntax:
////
////   {{ video(src="/videos/demo.mp4") }}
////   {{ video(src="/videos/demo.mp4", poster="/images/poster.jpg", title="Demo", caption="A demo video.", autoplay=true, muted=true, loop=true) }}
////   {{ video(src="https://example.com/stream.m3u8") }}
////   {{ video(src="https://example.com/stream", type="application/vnd.apple.mpegurl") }}
////
//// Only `src` is required. All other parameters are optional:
//// `type`, `poster`, `title`, `caption`, `autoplay`, `muted`, `loop`.
////
//// At build time `parse/1` validates and normalizes the parameters into a
//// typed `VideoEmbed`, and `view/1` emits semantic, non-executable, natively
//// usable markup. The generated markup contains no initialization scripts
//// and no player-specific naming; a runtime enhancement discovers the stable
//// `data-arata-video` marker and upgrades the native `<video>` in place.
////
//// Important invariants:
//// - an explicit `type` is authoritative over extension-based detection;
//// - generated text and attributes are escaped;
//// - unsafe source protocols are rejected;
//// - the native `<video>` and direct source link remain usable when runtime
////   enhancement fails.

import gleam.{type UtfCodepoint}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// Typed internal representation of a `video` shortcode.
///
/// `media_type` is the resolved MIME type: the explicit `type` parameter when
/// provided, otherwise the type inferred from the `src` extension. `None`
/// means the extension could not be recognized; the generated `<source>`
/// then omits the `type` attribute and the browser sniffs the resource.
pub type VideoEmbed {
  VideoEmbed(
    src: String,
    media_type: Option(String),
    poster: Option(String),
    title: Option(String),
    caption: Option(String),
    autoplay: Bool,
    muted: Bool,
    loop: Bool,
    is_hls: Bool,
  )
}

/// Build-time failure for `video` shortcode parameters.
pub type VideoError {
  /// `src` was absent or empty.
  MissingSrc
  /// A parameter name outside the stable contract was used.
  UnknownParam(param: String)
  /// A boolean parameter was not `true` or `false`.
  InvalidBoolean(param: String, value: String)
  /// A string parameter was used without a value (bare flag form).
  MissingValue(param: String)
  /// `src` or `poster` used a protocol outside the safe set.
  UnsafeSource(param: String, value: String)
}

/// Render a `VideoError` as a stable diagnostic message.
pub fn render_error(error: VideoError) -> String {
  case error {
    MissingSrc ->
      "video shortcode missing required parameter `src`"
    UnknownParam(param) ->
      "video shortcode unknown parameter `" <> param <> "`"
    InvalidBoolean(param, value) ->
      "video shortcode parameter `"
      <> param
      <> "` must be `true` or `false`, got `"
      <> value
      <> "`"
    MissingValue(param) ->
      "video shortcode parameter `" <> param <> "` requires a value"
    UnsafeSource(param, value) ->
      "video shortcode parameter `"
      <> param
      <> "` uses unsafe protocol: `"
      <> value
      <> "`"
  }
}

/// Parse a shortcode argument string into a typed `VideoEmbed`.
///
/// The argument string is the text inside `video(...)`, for example:
/// `src="/v.mp4", autoplay=true`. Values may be double-quoted,
/// single-quoted, or bare. Boolean parameters additionally accept the bare
/// flag form (`autoplay` means `autoplay=true`).
pub fn parse(arg_string: String) -> Result(VideoEmbed, VideoError) {
  case parse_params(arg_string) {
    Error(error) -> Error(error)
    Ok(fields) -> build_embed(fields)
  }
}

/// Parse and render an argument string in one step.
pub fn render(arg_string: String) -> Result(String, VideoError) {
  parse(arg_string)
  |> result.map(view)
}

/// Render the native, non-executable markup for a validated embed.
///
/// The output is a `<figure class="video-embed">` containing a native
/// `<video controls>` with a `<source>`, an in-video fallback link, an
/// optional `<figcaption>`, and a direct source link. Discovery attributes
/// are `data-arata-video` plus `data-video-src` / `data-video-type` /
/// `data-video-hls`; they contain no player-specific naming.
pub fn view(embed: VideoEmbed) -> String {
  let video_attrs =
    ["controls", "preload=\"metadata\"", "playsinline"]
    |> list.append(video_bool_attrs(embed))
    |> list.append(video_poster_attr(embed))
    |> list.append(video_label_attr(embed))

  let video =
    "<video class=\"video-embed-native\" "
    <> string.join(video_attrs, " ")
    <> ">"
    <> "<source src=\""
    <> escape_attr(embed.src)
    <> "\""
    <> media_type_attr(embed.media_type)
    <> ">"
    <> "<p>Your browser does not support video. "
    <> "<a href=\""
    <> escape_attr(embed.src)
    <> "\">Video source</a>.</p>"
    <> "</video>"

  let player_div =
    "<div class=\"video-embed-player\" data-video-player=\"true\">"
    <> video
    <> "</div>"

  let caption = caption_html(embed.title, embed.caption)

  let source_link =
    "<p class=\"video-embed-source\"><a href=\""
    <> escape_attr(embed.src)
    <> "\">Video source</a></p>"

  "<figure class=\"video-embed\" data-arata-video=\"true\" data-video-src=\""
  <> escape_attr(embed.src)
  <> "\""
  <> discovery_type_attr(embed.media_type)
  <> " data-video-hls=\""
  <> bool_to_string(embed.is_hls)
  <> "\">"
  <> player_div
  <> caption
  <> source_link
  <> "</figure>"
}

/// Resolve the effective MIME type for a source.
///
/// An explicit `type` value takes precedence over extension-based detection.
pub fn media_type_for(src: String, explicit: Option(String)) -> Option(String) {
  case explicit {
    Some(value) -> {
      let trimmed = string.trim(value)
      case trimmed {
        "" -> media_type_from_extension(src)
        _ -> Some(trimmed)
      }
    }
    None -> media_type_from_extension(src)
  }
}

/// Report whether a source should be treated as HLS.
pub fn is_hls_source(src: String, media_type: Option(String)) -> Bool {
  case media_type {
    Some(kind) -> is_hls_mime(kind)
    None -> is_hls_extension(src)
  }
}

/// Report whether a URL (or root-relative/relative path) is safe as a
/// video `src` or `poster`.
pub fn is_safe_source(url: String) -> Bool {
  let trimmed = string.trim(url)
  case trimmed {
    "" -> False
    _ -> !contains_whitespace(trimmed) && is_safe_form(trimmed)
  }
}

fn is_safe_form(url: String) -> Bool {
  let lowered = string.lowercase(url)
  case string.starts_with(lowered, "http://") {
    True -> has_host_after_scheme(lowered, 7)
    False ->
      case string.starts_with(lowered, "https://") {
        True -> has_host_after_scheme(lowered, 8)
        False -> is_safe_without_http(url, lowered)
      }
  }
}

fn is_safe_without_http(url: String, lowered: String) -> Bool {
  case string.starts_with(lowered, "/") {
    True -> True
    False ->
      case string.starts_with(lowered, "./") || string.starts_with(lowered, "../")
      {
        True -> True
        False -> has_no_scheme(url)
      }
  }
}

fn has_no_scheme(url: String) -> Bool {
  case string.split_once(url, ":") {
    Error(_) -> True
    Ok(#(before_colon, _)) ->
      string.contains(before_colon, "/")
      || string.contains(before_colon, "?")
      || string.contains(before_colon, "#")
  }
}

fn has_host_after_scheme(lowered: String, scheme_len: Int) -> Bool {
  let rest =
    string.slice(lowered, scheme_len, string.length(lowered) - scheme_len)
  let host = case string.split_once(rest, "/") {
    Ok(#(host, _)) -> host
    Error(_) -> rest
  }
  let host = case string.split_once(host, "?") {
    Ok(#(host, _)) -> host
    Error(_) -> host
  }
  let host = case string.split_once(host, "#") {
    Ok(#(host, _)) -> host
    Error(_) -> host
  }
  string.trim(host) != ""
}

fn contains_whitespace(value: String) -> Bool {
  string.contains(value, " ")
  || string.contains(value, "\t")
  || string.contains(value, "\n")
  || string.contains(value, "\r")
}

fn is_hls_mime(kind: String) -> Bool {
  let lowered = string.lowercase(string.trim(kind))
  lowered == "application/vnd.apple.mpegurl"
  || lowered == "application/x-mpegurl"
}

fn is_hls_extension(src: String) -> Bool {
  case extension_of(src) {
    Ok(ext) -> ext == "m3u8"
    Error(_) -> False
  }
}

fn media_type_from_extension(src: String) -> Option(String) {
  case extension_of(src) {
    Ok("mp4") -> Some("video/mp4")
    Ok("m4v") -> Some("video/mp4")
    Ok("webm") -> Some("video/webm")
    Ok("ogg") -> Some("video/ogg")
    Ok("ogv") -> Some("video/ogg")
    Ok("mov") -> Some("video/quicktime")
    Ok("m3u8") -> Some("application/vnd.apple.mpegurl")
    _ -> None
  }
}

fn extension_of(src: String) -> Result(String, Nil) {
  let path = strip_query_fragment(src)
  case string.split(path, ".") {
    [] -> Error(Nil)
    parts -> {
      let ext = list.last(parts) |> result.unwrap("")
      let ext = string.lowercase(string.trim(ext))
      case ext {
        "" -> Error(Nil)
        _ -> Ok(ext)
      }
    }
  }
}

fn strip_query_fragment(src: String) -> String {
  let without_query = case string.split_once(src, "?") {
    Ok(#(before, _)) -> before
    Error(_) -> src
  }
  case string.split_once(without_query, "#") {
    Ok(#(before, _)) -> before
    Error(_) -> without_query
  }
}

const known_params = [
  "src", "type", "poster", "title", "caption", "autoplay", "muted", "loop",
]

const bool_params = ["autoplay", "muted", "loop"]

fn parse_params(arg_string: String) -> Result(Dict(String, String), VideoError) {
  case split_params(arg_string) {
    Ok(chunks) -> collect_fields(chunks, dict.new())
    Error(error) -> Error(error)
  }
}

fn collect_fields(
  chunks: List(String),
  acc: Dict(String, String),
) -> Result(Dict(String, String), VideoError) {
  case chunks {
    [] -> Ok(acc)
    [chunk, ..rest] ->
      case parse_chunk(chunk) {
        Ok(#(key, value)) ->
          case list.contains(known_params, key) {
            False -> Error(UnknownParam(key))
            True -> collect_fields(rest, dict.insert(acc, key, value))
          }
        Error(error) -> Error(error)
      }
  }
}

fn parse_chunk(chunk: String) -> Result(#(String, String), VideoError) {
  let chunk = string.trim(chunk)
  case chunk {
    "" -> Error(MissingValue(""))
    _ -> parse_nonempty_chunk(chunk)
  }
}

fn parse_nonempty_chunk(chunk: String) -> Result(#(String, String), VideoError) {
  case string.split_once(chunk, "=") {
    Ok(#(key, raw_value)) -> {
      let key = string.lowercase(string.trim(key))
      let value = unquote(string.trim(raw_value))
      Ok(#(key, value))
    }
    Error(_) -> {
      let key = string.lowercase(string.trim(chunk))
      case list.contains(known_params, key) {
        False -> Error(UnknownParam(key))
        True ->
          case list.contains(bool_params, key) {
            True -> Ok(#(key, "true"))
            False -> Error(MissingValue(key))
          }
      }
    }
  }
}

fn split_params(arg_string: String) -> Result(List(String), VideoError) {
  case string.trim(arg_string) {
    "" -> Ok([])
    _ -> Ok(split_params_go(arg_string))
  }
}

fn split_params_go(arg_string: String) -> List(String) {
  let chars = string.to_utf_codepoints(arg_string)
  let #(chunks_rev, current) = split_loop(chars, [], "", False, False, False)
  chunk_strings(chunks_rev, current)
}

fn split_loop(
  chars: List(UtfCodepoint),
  chunks_rev: List(String),
  current: String,
  in_single: Bool,
  in_double: Bool,
  escaped: Bool,
) -> #(List(String), String) {
  case chars {
    [] -> #(chunks_rev, current)
    [char, ..rest] -> {
      let text = string.from_utf_codepoints([char])
      case escaped {
        True ->
          split_loop(rest, chunks_rev, current <> text, in_single, in_double, False)
        False ->
          case text {
            "\\" ->
              split_loop(rest, chunks_rev, current <> text, in_single, in_double, True)
            "'" ->
              case in_double {
                True ->
                  split_loop(
                    rest, chunks_rev, current <> text, in_single, in_double, False,
                  )
                False ->
                  split_loop(
                    rest, chunks_rev, current <> text, !in_single, in_double, False,
                  )
              }
            "\"" ->
              case in_single {
                True ->
                  split_loop(
                    rest, chunks_rev, current <> text, in_single, in_double, False,
                  )
                False ->
                  split_loop(
                    rest, chunks_rev, current <> text, in_single, !in_double, False,
                  )
              }
            "," ->
              case in_single || in_double {
                True ->
                  split_loop(
                    rest, chunks_rev, current <> text, in_single, in_double, False,
                  )
                False ->
                  split_loop(rest, [current, ..chunks_rev], "", in_single, in_double, False)
              }
            _ ->
              split_loop(rest, chunks_rev, current <> text, in_single, in_double, False)
          }
      }
    }
  }
}

fn chunk_strings(chunks_rev: List(String), current: String) -> List(String) {
  list.append(list.reverse(chunks_rev), [current])
  |> list.filter(fn(s) { string.trim(s) != "" })
}

fn unquote(value: String) -> String {
  let len = string.length(value)
  case len {
    0 -> value
    _ -> {
      let first = string.slice(value, 0, 1)
      let last = string.slice(value, len - 1, 1)
      case first, last {
        "\"", "\"" -> unescape(string.slice(value, 1, len - 2))
        "'", "'" -> unescape(string.slice(value, 1, len - 2))
        _, _ -> value
      }
    }
  }
}

fn unescape(value: String) -> String {
  value
  |> string.replace("\\\"", "\"")
  |> string.replace("\\'", "'")
  |> string.replace("\\\\", "\\")
}

fn build_embed(fields: Dict(String, String)) -> Result(VideoEmbed, VideoError) {
  case dict.get(fields, "src") {
    Error(_) -> Error(MissingSrc)
    Ok(raw_src) -> {
      let src = string.trim(raw_src)
      case src {
        "" -> Error(MissingSrc)
        _ ->
          case is_safe_source(src) {
            False -> Error(UnsafeSource("src", src))
            True ->
              case resolve_poster(fields) {
                Error(error) -> Error(error)
                Ok(poster) ->
                  case resolve_bools(fields) {
                    Error(error) -> Error(error)
                    Ok(#(autoplay, muted, loop)) -> {
                      let explicit = case dict.get(fields, "type") {
                        Ok(v) -> Some(v)
                        Error(_) -> None
                      }
                      let media_type = media_type_for(src, explicit)
                      let is_hls = is_hls_source(src, media_type)
                      Ok(VideoEmbed(
                        src: src,
                        media_type: media_type,
                        poster: poster,
                        title: optional_trimmed(fields, "title"),
                        caption: optional_trimmed(fields, "caption"),
                        autoplay: autoplay,
                        muted: muted,
                        loop: loop,
                        is_hls: is_hls,
                      ))
                    }
                  }
              }
          }
      }
    }
  }
}

fn resolve_poster(
  fields: Dict(String, String),
) -> Result(Option(String), VideoError) {
  case dict.get(fields, "poster") {
    Error(_) -> Ok(None)
    Ok(raw) -> {
      let poster = string.trim(raw)
      case poster {
        "" -> Ok(None)
        _ ->
          case is_safe_source(poster) {
            False -> Error(UnsafeSource("poster", poster))
            True -> Ok(Some(poster))
          }
      }
    }
  }
}

fn optional_trimmed(fields: Dict(String, String), key: String) -> Option(String) {
  case dict.get(fields, key) {
    Error(_) -> None
    Ok(raw) -> {
      let trimmed = string.trim(raw)
      case trimmed {
        "" -> None
        _ -> Some(trimmed)
      }
    }
  }
}

fn resolve_bools(
  fields: Dict(String, String),
) -> Result(#(Bool, Bool, Bool), VideoError) {
  case resolve_bool(fields, "autoplay") {
    Error(error) -> Error(error)
    Ok(autoplay) ->
      case resolve_bool(fields, "muted") {
        Error(error) -> Error(error)
        Ok(muted) ->
          case resolve_bool(fields, "loop") {
            Error(error) -> Error(error)
            Ok(loop) -> Ok(#(autoplay, muted, loop))
          }
      }
  }
}

fn resolve_bool(
  fields: Dict(String, String),
  key: String,
) -> Result(Bool, VideoError) {
  case dict.get(fields, key) {
    Error(_) -> Ok(False)
    Ok(raw) -> {
      let lowered = string.lowercase(string.trim(raw))
      case lowered {
        "true" -> Ok(True)
        "false" -> Ok(False)
        _ -> Error(InvalidBoolean(key, string.trim(raw)))
      }
    }
  }
}

fn video_bool_attrs(embed: VideoEmbed) -> List(String) {
  let autoplay = case embed.autoplay {
    True -> ["autoplay"]
    False -> []
  }
  let muted = case embed.muted {
    True -> ["muted"]
    False -> []
  }
  let loop = case embed.loop {
    True -> ["loop"]
    False -> []
  }
  list.append(autoplay, list.append(muted, loop))
}

fn video_poster_attr(embed: VideoEmbed) -> List(String) {
  case embed.poster {
    Some(poster) -> ["poster=\"" <> escape_attr(poster) <> "\""]
    None -> []
  }
}

fn video_label_attr(embed: VideoEmbed) -> List(String) {
  case embed.title {
    Some(title) -> ["aria-label=\"" <> escape_attr(title) <> "\""]
    None -> []
  }
}

fn media_type_attr(media_type: Option(String)) -> String {
  case media_type {
    Some(kind) -> " type=\"" <> escape_attr(kind) <> "\""
    None -> ""
  }
}

fn discovery_type_attr(media_type: Option(String)) -> String {
  case media_type {
    Some(kind) -> " data-video-type=\"" <> escape_attr(kind) <> "\""
    None -> ""
  }
}

fn caption_html(title: Option(String), caption: Option(String)) -> String {
  case title, caption {
    None, None -> ""
    Some(text), None -> "<figcaption>" <> escape_text(text) <> "</figcaption>"
    None, Some(text) -> "<figcaption>" <> escape_text(text) <> "</figcaption>"
    Some(title_text), Some(caption_text) ->
      "<figcaption><span class=\"video-embed-title\">"
      <> escape_text(title_text)
      <> "</span> "
      <> escape_text(caption_text)
      <> "</figcaption>"
  }
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

fn escape_text(value: String) -> String {
  value
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
}

fn escape_attr(value: String) -> String {
  value
  |> escape_text
  |> string.replace("\"", "&quot;")
  |> string.replace("'", "&#39;")
}
