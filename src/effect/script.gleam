//// Script effect: runtime enhancement bridge for MathJax and Mermaid.
////
//// The actual browser work lives in `src/ffi/script.ffi.mjs`; this module keeps
//// Lustre effects typed on the Gleam side and passes runtime asset URLs from
//// configuration into JavaScript.
////
//// Important invariants:
//// - `mathjax_cdn_url` must be passed from `config.gleam` to the FFI. The FFI
////   should not be forced to guess the asset URL.
//// - `mermaid_cdn_url` must be passed from `config.gleam` to the FFI when
////   Mermaid rendering is enabled.
//// - Callers are responsible for checking feature toggles before invoking these
////   effects. For example, when `mathjax_enabled` is `False`, do not call
////   `typeset_math`.
//// - These effects are safe to call on pages without math or Mermaid blocks.
////   The JavaScript side handles empty documents as a no-op.
//// - The JavaScript side must never throw into the SPA if an external/local
////   runtime asset fails to load.
////
//// MathJax:
//// - Typesets inline and block TeX after the SPA has rendered the current view.
//// - The URL is configurable so users can choose jsDelivr, another CDN, or a
////   vendored local asset such as `/js/tex-mml-chtml.js`.
////
//// Mermaid:
//// - Renders native fenced Markdown code blocks such as:
////     ```mermaid
////     graph TD
////       A --> B
////     ```
//// - Also keeps compatibility with legacy shortcode output that already emits
////   `.mermaid` elements.
//// - `is_dark` selects the runtime Mermaid theme.

import lustre/effect.{type Effect}

/// Typeset MathJax in the current document.
///
/// `mathjax_cdn_url` is the runtime asset URL from configuration. It may point
/// to an external CDN or to a local vendored asset, for example:
///
///   /js/tex-mml-chtml.js
///
/// This function intentionally does not know about `mathjax_enabled`; the caller
/// should check that toggle before creating this effect.
pub fn typeset_math(mathjax_cdn_url: String) -> Effect(Nil) {
  use _ <- effect.from
  do_typeset_math(mathjax_cdn_url)
  Nil
}

/// Render Mermaid diagrams in the current document.
///
/// `is_dark` selects the Mermaid theme on the JavaScript side.
/// `mermaid_cdn_url` is the runtime asset URL from configuration. It may point
/// to an external CDN or to a local vendored ESM asset, for example:
///
///   /js/mermaid.esm.min.mjs
///
/// This function intentionally does not know about `mermaid_enabled`; the
/// caller should check that toggle before creating this effect.
pub fn render_mermaid(is_dark: Bool, mermaid_cdn_url: String) -> Effect(Nil) {
  use _ <- effect.from
  do_render_mermaid(is_dark, mermaid_cdn_url)
  Nil
}

@external(javascript, "../ffi/script.ffi.mjs", "typeset_math")
fn do_typeset_math(mathjax_cdn_url: String) -> Nil

@external(javascript, "../ffi/script.ffi.mjs", "render_mermaid")
fn do_render_mermaid(is_dark: Bool, mermaid_cdn_url: String) -> Nil
