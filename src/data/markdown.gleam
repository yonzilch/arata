//// Markdown rendering: converts markdown strings to HTML using the mork
//// parser.
////
//// arata parses Markdown at build time, not in the browser. The resulting HTML
//// is stored in `dist/content_index.json` and rendered by the SPA through
//// `unsafe_raw_html`.
////
//// Important:
//// mork's extended Markdown features are opt-in. Using `mork.parse/1` only
//// parses the default CommonMark subset, so GFM tables like:
////
////   | Left | Right |
////   | ---- | ----- |
////   | foo  | bar   |
////
//// would be treated as a plain paragraph. We use `parse_with_options` with
//// `tables: True` so table blocks become real `<table>` HTML.
////
//// We intentionally keep `heading_ids: False` because arata adds heading IDs
//// later in `content/headings.gleam` (called from `content/loader.gleam`).
//// Enabling mork's heading IDs here would risk duplicate/conflicting IDs.
////
//// We also keep `strip_frontmatter: False` because arata already splits TOML
//// frontmatter (`+++ ... +++`) before calling this module.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import mork
import mork/document.{type Options, Options}
import shortcodes/video

/// Convert a Markdown string to its final HTML: every rendered `<table>` is
/// wrapped in a horizontally scrollable `<div class="table-wrap">` so wide
/// tables scroll inside the content column instead of stretching the page
/// (see `wrap_tables`).
pub fn to_html(markdown: String) -> String {
  let ast =
    mork.parse_with_options(options: markdown_options(), input: markdown)

  mork.to_html(ast)
  |> wrap_tables
}
/// Expand `video` shortcodes in Markdown before it reaches mork.
///
/// Only the generic `video` shortcode is recognized here; other `{{ ... }}`
/// constructs are passed through unchanged so existing content is preserved.
/// Fenced code blocks and inline code spans are never expanded, which keeps
/// documentation examples literal.
///
/// Returns `Error` with a stable diagnostic on the first invalid `video`
/// shortcode (missing `src`, unknown parameter, invalid boolean, unsafe
/// protocol). Callers in the build pipeline turn that error into a build
/// failure naming the source file.
pub fn expand_shortcodes(markdown: String) -> Result(String, String) {
  expand_fenced_segments(split_fenced(markdown), "", True)
}

fn expand_fenced_segments(
  segments: List(#(Bool, String)),
  acc: String,
  first: Bool,
) -> Result(String, String) {
  case segments {
    [] -> Ok(acc)
    [#(True, text), ..rest] -> {
      let next = case first {
        True -> acc <> text
        False -> acc <> "\n" <> text
      }
      expand_fenced_segments(rest, next, False)
    }
    [#(False, text), ..rest] ->
      case expand_outside_inline_code(text) {
        Ok(expanded) -> {
          let next = case first {
            True -> acc <> expanded
            False -> acc <> "\n" <> expanded
          }
          expand_fenced_segments(rest, next, False)
        }
        Error(message) -> Error(message)
      }
  }
}

/// Split Markdown into fenced-code and text segments.
///
/// Fence markers (``` or ~~~) are recognized at the start of a trimmed line.
/// Segments hold lines joined by `\n`; the caller joins segments with `\n`
/// so the reassembled text is byte-identical to the input.
fn split_fenced(markdown: String) -> List(#(Bool, String)) {
  let lines = string.split(markdown, "\n")
  split_lines(lines, None, [], [])
}

fn split_lines(
  lines: List(String),
  fence: Option(String),
  segments_rev: List(#(Bool, String)),
  current_rev: List(String),
) -> List(#(Bool, String)) {
  case lines {
    [] -> finish_segment(fence, segments_rev, current_rev)
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case fence {
        Some(marker) ->
          case string.starts_with(trimmed, marker) {
            True -> {
              let code_text =
                [line, ..current_rev]
                |> list.reverse()
                |> string.join("\n")
              split_lines(rest, None, [#(True, code_text), ..segments_rev], [])
            }
            False -> split_lines(rest, fence, segments_rev, [line, ..current_rev])
          }
        None ->
          case fence_marker(trimmed) {
            Some(marker) -> {
              let flushed = flush_text_lines(segments_rev, current_rev)
              split_lines(rest, Some(marker), flushed, [line])
            }
            None -> split_lines(rest, None, segments_rev, [line, ..current_rev])
          }
      }
    }
  }
}

fn finish_segment(
  fence: Option(String),
  segments_rev: List(#(Bool, String)),
  current_rev: List(String),
) -> List(#(Bool, String)) {
  case current_rev {
    [] -> list.reverse(segments_rev)
    _ -> {
      let text =
        current_rev
        |> list.reverse()
        |> string.join("\n")
      let is_code = case fence {
        Some(_) -> True
        None -> False
      }
      list.append(list.reverse(segments_rev), [#(is_code, text)])
    }
  }
}

fn flush_text_lines(
  segments_rev: List(#(Bool, String)),
  current_rev: List(String),
) -> List(#(Bool, String)) {
  case current_rev {
    [] -> segments_rev
    _ -> {
      let text =
        current_rev
        |> list.reverse()
        |> string.join("\n")
      [#(False, text), ..segments_rev]
    }
  }
}

fn fence_marker(trimmed: String) -> Option(String) {
  case string.starts_with(trimmed, "```") {
    True -> Some("```")
    False ->
      case string.starts_with(trimmed, "~~~") {
        True -> Some("~~~")
        False -> None
      }
  }
}

/// Expand `video` shortcodes outside inline code spans.
fn expand_outside_inline_code(text: String) -> Result(String, String) {
  expand_scanning(text, "", False)
}
fn expand_scanning(
  text: String,
  acc: String,
  in_code: Bool,
) -> Result(String, String) {
  case string.split_once(text, "`") {
    Error(_) -> expand_braces(text, acc)
    Ok(#(before, rest)) -> {
      let #(run, after_run) = take_backtick_run(rest)
      case in_code {
        True -> expand_scanning(after_run, acc <> before <> run, False)
        False ->
          case expand_braces(before, acc) {
            Ok(expanded) -> expand_scanning(after_run, expanded <> run, True)
            Error(message) -> Error(message)
          }
      }
    }
  }
}

fn take_backtick_run(text: String) -> #(String, String) {
  take_backtick_run_go(text, "`")
}

fn take_backtick_run_go(text: String, run: String) -> #(String, String) {
  case string.split_once(text, "`") {
    Ok(#("", after)) -> take_backtick_run_go(after, run <> "`")
    _ -> #(run, text)
  }
}



/// Expand `{{ video(...) }}` occurrences in one code-free fragment.
fn expand_braces(
  text: String,
  acc: String,
) -> Result(String, String) {
  case string.split_once(text, "{{") {
    Error(_) -> Ok(acc <> text)
    Ok(#(before, rest)) ->
      case string.split_once(rest, "}}") {
        Error(_) -> Ok(acc <> before <> "{{" <> rest)
        Ok(#(inner, after)) ->
          case video_args(inner) {
            Some(arg_string) ->
              case video.render(arg_string) {
                Ok(html) -> expand_braces(after, acc <> before <> html)
                Error(error) -> Error(video.render_error(error))
              }
            None -> expand_braces(after, acc <> before <> "{{" <> inner <> "}}")
          }
      }
  }
}

/// Extract the argument string when `inner` is a `video(...)` shortcode.
///
/// Returns `None` for non-video constructs, which are left verbatim. Whitespace
/// is tolerated around the name and parentheses.
fn video_args(inner: String) -> Option(String) {
  let trimmed = string.trim(inner)
  case string.starts_with(trimmed, "video") {
    False -> None
    True -> parse_video_call(trimmed)
  }
}

fn parse_video_call(trimmed: String) -> Option(String) {
  let after_name = string.slice(trimmed, 5, string.length(trimmed) - 5)
  let rest = string.trim(after_name)
  case rest {
    "" -> None
    _ ->
      case string.starts_with(rest, "(") && string.ends_with(rest, ")") {
        False -> None
        True ->
          Some(string.slice(rest, 1, string.length(rest) - 2))
      }
  }
}

/// Markdown extension options used by arata.
///
/// Keep this centralized so all Markdown rendering paths behave consistently.
fn markdown_options() -> Options {
  Options(
    strip_frontmatter: False,
    footnotes: True,
    heading_ids: False,
    tables: True,
    tasklists: True,
    emojis: True,
    autolinks: True,
  )
}

// TABLE WRAPPING --------------------------------------------------------------
//
// `overflow-x: auto` only creates a scroll container on block-level boxes.
// Making the `<table>` element itself `display: block` would break the
// anonymous-table-box model (`border-collapse: collapse` stops applying to
// the inner table box and cell borders double up), so the table is left
// untouched and the scroll container lives on the wrapper div. The matching
// rule is `.table-wrap { overflow-x: auto; }` in `src/css/post.css`,
// mirroring how `pre` already handles oversized code blocks.

/// Opening tag of the wrapper emitted by `wrap_tables`. Also used to detect
/// tables that are already wrapped (raw HTML in a post), so re-running the
/// transform never double-wraps.
const wrap_open = "<div class=\"table-wrap\">"

/// Wrap every `<table>…</table>` in rendered HTML with
/// `<div class="table-wrap">…</div>`.
///
/// Tables are matched textually on `<table` / `</table>`, the same approach
/// `content/headings.gleam` uses for headings. Escaped code samples
/// (`&lt;table`) inside `pre`/`code` are never matched because the angle
/// brackets are entity-encoded in the rendered HTML. Nested tables (only
/// possible via raw HTML in markdown) are handled by counting open/close tags
/// so each table finds its own matching close. Unbalanced input is passed
/// through unchanged rather than wrapped half-open.
pub fn wrap_tables(html: String) -> String {
  case string.split_once(html, "<table") {
    Error(_) -> html
    Ok(#(before, rest)) ->
      case find_matching_close(rest, 1) {
        // Unbalanced table markup: leave the whole fragment untouched.
        Error(_) -> html
        Ok(#(inner, after)) ->
          case string.ends_with(before, wrap_open) {
            // Already wrapped — keep the table as-is and keep scanning.
            True ->
              before <> "<table" <> inner <> "</table>" <> wrap_tables(after)
            False -> {
              // Nested tables inside this one are wrapped too.
              let wrapped =
                wrap_open <> "<table" <> wrap_tables(inner) <> "</table></div>"
              before <> wrapped <> wrap_tables(after)
            }
          }
      }
  }
}

/// Find the `</table>` matching a `<table` whose remainder `fragment` starts
/// right after the opening tag. `depth` is the number of tables currently
/// open. Returns the full content between the opening tag and its matching
/// close (including any nested tables' own tags) and everything after the
/// close, or `Error(Nil)` when no matching close exists.
fn find_matching_close(
  fragment: String,
  depth: Int,
) -> Result(#(String, String), Nil) {
  case string.split_once(fragment, "</table>") {
    Error(_) -> Error(Nil)
    Ok(#(before, after)) -> {
      let nested = list.length(string.split(before, "<table")) - 1
      case depth + nested {
        // This close tag belongs to the table we started from.
        1 -> Ok(#(before, after))
        // A nested table's close tag: keep the segment (with its close tag
        // restored) and continue searching after it.
        deeper ->
          find_matching_close(after, deeper - 1)
          |> result.map(fn(pair) {
            let #(inner, rest) = pair
            #(before <> "</table>" <> inner, rest)
          })
      }
    }
  }
}
