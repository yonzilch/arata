//// Script effect: dynamically loads and invokes MathJax and Mermaid after
//// each post view renders, mirroring apollo's MathJax config and
//// `static/js/main.js::mermaidRender`.
////
//// Because arata doesn't yet have a custom `index.html` (Phase 17), the
//// scripts are loaded lazily on first use via the FFI: if MathJax/mermaid are
//// not yet on the page, the FFI injects the `<script>` tags, waits for them
//// to load, then calls the render API.
////
//// MathJax config matches apollo's: `inlineMath [['$','$'], ['\\(','\\)']]`.
//// Mermaid is initialized with theme "dark" or "neutral" based on the current
//// effective theme, and re-rendered on theme change (apollo's `mermaidRender`
//// restores the original innerHTML, clears the `processed` flag, then calls
//// `mermaid.run()`).
////
//// The FFI lives in `src/ffi/script.ffi.mjs`. The `@external` declarations
//// have no-op Gleam fallback bodies so the project builds on Erlang.

import lustre/effect.{type Effect}

/// Typeset math (MathJax) in the current document. Loads MathJax lazily on
/// first call. Safe to call on pages with no math — MathJax will just find
/// nothing to typeset.
pub fn typeset_math() -> Effect(Nil) {
  use _ <- effect.from
  do_typeset_math()
  Nil
}

/// Render mermaid diagrams in the current document. `is_dark` selects the
/// mermaid theme ("dark" or "neutral"). Loads mermaid lazily on first call.
/// Safe to call on pages with no mermaid blocks.
pub fn render_mermaid(is_dark: Bool) -> Effect(Nil) {
  use _ <- effect.from
  do_render_mermaid(is_dark)
  Nil
}

@external(javascript, "ffi/script.ffi.mjs", "typeset_math")
fn do_typeset_math() -> Nil

@external(javascript, "ffi/script.ffi.mjs", "render_mermaid")
fn do_render_mermaid(is_dark: Bool) -> Nil
