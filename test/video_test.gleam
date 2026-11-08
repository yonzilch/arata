//// Tests for the generic `video` shortcode.
////
//// Covers parsing, validation, escaping, generated markup, media-type
//// detection, HLS selection, and Markdown expansion. Runtime player
//// initialization, repeated initialization, cleanup, and dependency
//// loading live in the DOM FFI (`src/ffi/video.ffi.mjs`); the source checks
//// at the end of this file guard its structural invariants because Gleeunit
//// cannot run a browser DOM.

import data/markdown
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import gleeunit/should
import shortcodes/video
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

fn must_parse(arg_string: String) -> video.VideoEmbed {
  let assert Ok(embed) = video.parse(arg_string)
  embed
}

fn must_render(arg_string: String) -> String {
  let assert Ok(html) = video.render(arg_string)
  html
}

fn contains_lower(haystack: String, needle: String) -> Bool {
  string.contains(string.lowercase(haystack), string.lowercase(needle))
}

// PARSING -------------------------------------------------------------------

pub fn minimal_src_only_parses_test() {
  let embed = must_parse("src=\"/videos/demo.mp4\"")
  embed.src |> should.equal("/videos/demo.mp4")
  embed.autoplay |> should.equal(False)
  embed.muted |> should.equal(False)
  embed.loop |> should.equal(False)
  embed.is_hls |> should.equal(False)
}

pub fn full_params_parse_test() {
  let embed =
    must_parse(
      "src=\"/videos/demo.mp4\", poster=\"/images/poster.jpg\", title=\"Demo\", caption=\"A demo.\", autoplay=true, muted=true, loop=true",
    )
  embed.poster |> should.equal(Some("/images/poster.jpg"))
  embed.title |> should.equal(Some("Demo"))
  embed.caption |> should.equal(Some("A demo."))
  embed.autoplay |> should.equal(True)
  embed.muted |> should.equal(True)
  embed.loop |> should.equal(True)
}

pub fn boolean_defaults_are_false_test() {
  let embed = must_parse("src=\"/v.mp4\"")
  embed.autoplay |> should.equal(False)
  embed.muted |> should.equal(False)
  embed.loop |> should.equal(False)
}

pub fn bare_boolean_flag_means_true_test() {
  let embed = must_parse("src=\"/v.mp4\", autoplay, muted=false")
  embed.autoplay |> should.equal(True)
  embed.muted |> should.equal(False)
}

pub fn single_quoted_and_bare_values_parse_test() {
  let embed = must_parse("src='/v.mp4', autoplay=true")
  embed.src |> should.equal("/v.mp4")
  embed.autoplay |> should.equal(True)
}

pub fn quoted_value_with_comma_is_one_param_test() {
  let embed = must_parse("src=\"/v.mp4\", caption=\"Hello, world\"")
  embed.caption |> should.equal(Some("Hello, world"))
}

// VALIDATION ----------------------------------------------------------------

pub fn missing_src_is_error_test() {
  let result = video.parse("poster=\"/p.jpg\"")
  result |> should.be_error()
  case result {
    Error(error) -> {
      video.render_error(error)
      |> should.equal("video shortcode missing required parameter `src`")
    }
    Ok(_) -> panic as "expected error"
  }
}

pub fn empty_src_is_error_test() {
  video.parse("src=\"\"") |> should.be_error()
}

pub fn unknown_param_is_error_test() {
  let result = video.parse("src=\"/v.mp4\", renderer=\"artplayer\"")
  result |> should.be_error()
  case result {
    Error(error) -> {
      video.render_error(error)
      |> string.contains("unknown parameter")
      |> should.be_true()
    }
    Ok(_) -> panic as "expected error"
  }
}

pub fn invalid_boolean_is_error_test() {
  let result = video.parse("src=\"/v.mp4\", autoplay=\"yes\"")
  result |> should.be_error()
  case result {
    Error(error) -> {
      video.render_error(error)
      |> string.contains("must be `true` or `false`")
      |> should.be_true()
    }
    Ok(_) -> panic as "expected error"
  }
}

pub fn unsafe_src_protocols_are_rejected_test() {
  video.parse("src=\"javascript:alert(1)\"") |> should.be_error()
  video.parse("src=\"data:text/html;base64,xxx\"") |> should.be_error()
  video.parse("src=\"file:///etc/passwd\"") |> should.be_error()
}

pub fn safe_sources_are_accepted_test() {
  must_parse("src=\"https://example.com/v.mp4\"")
  must_parse("src=\"http://example.com/v.mp4\"")
  must_parse("src=\"/videos/demo.mp4\"")
  must_parse("src=\"videos/demo.mp4\"")
  must_parse("src=\"./demo.mp4\"")
  must_parse("src=\"../demo.mp4\"")
}

pub fn unsafe_poster_is_rejected_test() {
  video.parse("src=\"/v.mp4\", poster=\"javascript:x\"") |> should.be_error()
}

// MEDIA TYPE + HLS SELECTION -------------------------------------------------

pub fn explicit_type_takes_precedence_test() {
  video.media_type_for("/v.mp4", Some("video/webm"))
  |> should.equal(Some("video/webm"))
  video.media_type_for("/stream", Some("video/mp4"))
  |> should.equal(Some("video/mp4"))
}

pub fn extension_detection_test() {
  video.media_type_for("/v.mp4", None) |> should.equal(Some("video/mp4"))
  video.media_type_for("/v.webm", None) |> should.equal(Some("video/webm"))
  video.media_type_for("/v.m3u8", None)
  |> should.equal(Some("application/vnd.apple.mpegurl"))
  video.media_type_for("/stream?token=abc", None) |> should.equal(None)
  video.media_type_for("/v.mp4?x=1#frag", None)
  |> should.equal(Some("video/mp4"))
}

pub fn hls_selection_follows_resolved_type_test() {
  video.is_hls_source("/v.m3u8", Some("application/vnd.apple.mpegurl"))
  |> should.be_true()
  video.is_hls_source("/v.mp4", Some("video/mp4")) |> should.be_false()
  // Explicit non-HLS type wins over an .m3u8 extension.
  video.is_hls_source("/v.m3u8", Some("video/mp4")) |> should.be_false()
}

pub fn hls_extension_fallback_test() {
  video.is_hls_source("/v.m3u8", None) |> should.be_true()
  video.is_hls_source("/v.m3u8?sig=1", None) |> should.be_true()
  video.is_hls_source("/v.mp4", None) |> should.be_false()
}

pub fn parsed_hls_flag_test() {
  must_parse("src=\"https://example.com/stream.m3u8\"").is_hls
  |> should.be_true()
  must_parse("src=\"https://example.com/v.mp4\"").is_hls |> should.be_false()
  must_parse("src=\"https://example.com/stream\", type=\"application/vnd.apple.mpegurl\"")
  |> fn(embed) { embed.is_hls }
  |> should.be_true()
}

// MARKUP --------------------------------------------------------------------

pub fn minimal_markup_is_native_and_discoverable_test() {
  let html = must_render("src=\"/videos/demo.mp4\"")
  string.contains(html, "<video") |> should.be_true()
  string.contains(html, "controls") |> should.be_true()
  string.contains(html, "<source") |> should.be_true()
  string.contains(html, "data-arata-video") |> should.be_true()
  string.contains(html, "data-video-src=\"/videos/demo.mp4\"")
  |> should.be_true()
  string.contains(html, "data-video-hls=\"false\"") |> should.be_true()
  string.contains(html, "Video source") |> should.be_true()
}

pub fn generated_markup_has_no_script_or_player_naming_test() {
  let html = must_render("src=\"/v.mp4\", title=\"Demo\", caption=\"Cap\"")
  string.contains(html, "<script") |> should.be_false()
  contains_lower(html, "artplayer") |> should.be_false()
  contains_lower(html, "script") |> should.be_false()
}

pub fn title_and_caption_render_as_figcaption_test() {
  let html = must_render("src=\"/v.mp4\", title=\"My Title\", caption=\"My caption\"")
  string.contains(html, "<figcaption>") |> should.be_true()
  string.contains(html, "My Title") |> should.be_true()
  string.contains(html, "My caption") |> should.be_true()
  string.contains(html, "aria-label=\"My Title\"") |> should.be_true()
}

pub fn poster_and_bool_attrs_render_test() {
  let html =
    must_render(
      "src=\"/v.mp4\", poster=\"/p.jpg\", autoplay=true, muted=true, loop=true",
    )
  string.contains(html, "poster=\"/p.jpg\"") |> should.be_true()
  string.contains(html, "autoplay") |> should.be_true()
  string.contains(html, "muted") |> should.be_true()
  string.contains(html, "loop") |> should.be_true()
}

pub fn false_bool_attrs_are_omitted_test() {
  let html = must_render("src=\"/v.mp4\", autoplay=false")
  // `autoplay` must not appear as an attribute (would require matching a
  // standalone word, so check the attribute form directly).
  string.contains(html, " autoplay") |> should.be_false()
  string.contains(html, " muted") |> should.be_false()
}

pub fn escaping_test() {
  let html = must_render("src=\"/v.mp4\", title=\"<b>Oops</b>\", caption=\"A & B\"")
  string.contains(html, "<b>Oops</b>") |> should.be_false()
  string.contains(html, "&lt;b&gt;") |> should.be_true()
  string.contains(html, "A &amp; B") |> should.be_true()
}

pub fn rendering_is_stable_test() {
  // Re-rendering the same embed produces identical markup, so repeated
  // initialization inputs are deterministic and multiple embeds stay
  // independent.
  let first = must_render("src=\"/a.mp4\"")
  let second = must_render("src=\"/a.mp4\"")
  first |> should.equal(second)

  let two =
    must_render("src=\"/a.mp4\"") <> must_render("src=\"/b.m3u8\"")
  string.contains(two, "/a.mp4") |> should.be_true()
  string.contains(two, "/b.m3u8") |> should.be_true()
  // Both embeds carry the discovery marker.
  list.length(string.split(two, "data-arata-video")) - 1
  |> should.equal(2)
}

// MARKDOWN EXPANSION --------------------------------------------------------

pub fn expansion_renders_video_test() {
  let assert Ok(html) =
    markdown.expand_shortcodes("Before\n\n{{ video(src=\"/v.mp4\") }}\n\nAfter")
  string.contains(html, "<figure") |> should.be_true()
  string.contains(html, "data-arata-video") |> should.be_true()
  string.contains(html, "Before") |> should.be_true()
  string.contains(html, "After") |> should.be_true()
}

pub fn expansion_errors_on_invalid_video_test() {
  markdown.expand_shortcodes("{{ video(poster=\"/p.jpg\") }}")
  |> should.be_error()
  markdown.expand_shortcodes("{{ video(src=\"/v.mp4\", autoplay=\"yes\") }}")
  |> should.be_error()
}

pub fn expansion_skips_fenced_code_test() {
  let md = "```markdown\n{{ video(src=\"/v.mp4\") }}\n```"
  let assert Ok(html) = markdown.expand_shortcodes(md)
  html |> should.equal(md)
}

pub fn expansion_skips_inline_code_test() {
  let md = "`{{ video(src=\"/v.mp4\") }}`"
  let assert Ok(html) = markdown.expand_shortcodes(md)
  html |> should.equal(md)
}

pub fn expansion_leaves_non_video_constructs_test() {
  let md = "{{ note(src=\"/v.mp4\") }} and {{ something }}"
  let assert Ok(html) = markdown.expand_shortcodes(md)
  html |> should.equal(md)
}

pub fn expansion_leaves_plain_markdown_test() {
  let md = "# Title\n\nHello **world**."
  let assert Ok(html) = markdown.expand_shortcodes(md)
  html |> should.equal(md)
}
pub fn expansion_preserves_fences_with_surrounding_text_test() {
  // Regression: segment joining must keep `\n` separators, otherwise the
  // closing fence (e.g. "```Hello") stops being a valid fence and the rest
  // of the document becomes one code block.
  let md = "Intro\n\n```gleam\nfn main() { Nil }\n```\n\nOutro"
  let assert Ok(html) = markdown.expand_shortcodes(md)
  html |> should.equal(md)
}

pub fn expansion_preserves_fence_at_start_test() {
  let md = "```\ncode\n```\nHello"
  let assert Ok(html) = markdown.expand_shortcodes(md)
  html |> should.equal(md)
}

pub fn expanded_fence_renders_with_following_text_test() {
  // Expand then render; text after the fence must be a paragraph, not
  // code content.
  let md = "```\ncode\n```\nHello"
  let assert Ok(expanded) = markdown.expand_shortcodes(md)
  let html = markdown.to_html(expanded)
  string.contains(html, "<pre>") |> should.be_true()
  string.contains(html, "</pre>") |> should.be_true()
  string.contains(html, "<p>Hello</p>") |> should.be_true()
}

// FFI STRUCTURAL INVARIANTS -------------------------------------------------
// The DOM enhancement cannot run under Gleeunit, so these assertions guard
// the required lifecycle behavior directly in the FFI source: lazy player
// loading, native-HLS preference, duplicate prevention, stale discard, and
// idempotent cleanup.

fn ffi_source() -> String {
  let assert Ok(contents) = simplifile.read("src/ffi/video.ffi.mjs")
  contents
}

pub fn ffi_lazy_loads_only_with_video_test() {
  let source = ffi_source()
  string.contains(source, "[data-arata-video]") |> should.be_true()
  string.contains(source, "loadArtPlayer") |> should.be_true()
  string.contains(source, "loadHls") |> should.be_true()
  // No eager static import of the player bundle.
  string.contains(source, "import Artplayer") |> should.be_false()
}

pub fn ffi_prefers_native_hls_test() {
  let source = ffi_source()
  string.contains(source, "canPlayType") |> should.be_true()
  string.contains(source, "nativeHlsSupported") |> should.be_true()
  string.contains(source, "needsHlsProvider") |> should.be_true()
}

pub fn ffi_duplicate_stale_and_cleanup_guards_test() {
  let source = ffi_source()
  string.contains(source, "instances.has") |> should.be_true()
  string.contains(source, "generation") |> should.be_true()
  string.contains(source, "document.contains") |> should.be_true()
  string.contains(source, "destroy") |> should.be_true()
  string.contains(source, "pruneDetached") |> should.be_true()
  string.contains(source, "cleanup_videos") |> should.be_true()
  string.contains(source, "enhance_videos") |> should.be_true()
}

pub fn effect_exposes_enhance_and_cleanup_test() {
  let assert Ok(source) = simplifile.read("src/effect/video.gleam")
  string.contains(source, "enhance") |> should.be_true()
  string.contains(source, "cleanup") |> should.be_true()
  string.contains(source, "video.ffi.mjs") |> should.be_true()
  string.contains(source, "artplayer_url") |> should.be_true()
  string.contains(source, "hls_url") |> should.be_true()
}

pub fn ffi_defaults_to_pinned_versions_test() {
  let source = ffi_source()
  string.contains(source, "artplayer@5.4.0") |> should.be_true()
  string.contains(source, "hls.js@1.7.4") |> should.be_true()
  string.contains(source, "artplayer@5.2.0") |> should.be_false()
  string.contains(source, "hls.js@1.5.18") |> should.be_false()
}

pub fn ffi_accepts_configured_urls_test() {
  let source = ffi_source()
  string.contains(source, "normalizeUrl") |> should.be_true()
  string.contains(source, "DEFAULT_ARTPLAYER_URL") |> should.be_true()
  string.contains(source, "DEFAULT_HLS_URL") |> should.be_true()
}
