//// Markdown rendering: converts markdown strings to HTML using the mork
//// parser (a pure-Gleam CommonMark + GFM implementation).
////
//// This replaces the pre-rendered HTML bodies in the sample content with
//// real markdown strings that are parsed at render time. This is the
//// foundation for the future content pipeline (ROADMAP Phase 17), where
//// posts will be loaded from `.md` files.
////
//// Usage:
////   let html = markdown.to_html("# Hello\n\nWorld")
////   // => "<h1>Hello</h1>\n<p>World</p>"

import mork

/// Convert a markdown string to HTML. Returns the HTML string.
pub fn to_html(markdown: String) -> String {
  let ast = mork.parse(markdown)
  mork.to_html(ast)
}
