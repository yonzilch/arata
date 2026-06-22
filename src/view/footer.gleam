//// Site footer: a copyright line.
////
//// apollo's `base.html` has no explicit `<footer>`; arata adds a minimal one
//// so the bottom of every page has the copyright.

import config.{type Config}
import lustre/element.{type Element}
import lustre/element/html

/// Hardcoded copyright year. Phase 4+ replaces this with a small FFI call to
/// `new Date().getFullYear()` so the footer stays current without a rebuild.
const current_year = "2026"

/// Render the site footer.
pub fn view(config: Config) -> Element(msg) {
  html.footer([], [
    html.span([], [
      html.text("© " <> current_year <> " " <> config.title),
    ]),
  ])
}
