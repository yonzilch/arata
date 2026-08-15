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

import mork
import mork/document.{type Options, Options}

/// Convert a Markdown string to HTML.
pub fn to_html(markdown: String) -> String {
  let ast =
    mork.parse_with_options(options: markdown_options(), input: markdown)

  mork.to_html(ast)
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
