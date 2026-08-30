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
import gleam/result
import gleam/string
import mork
import mork/document.{type Options, Options}

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
