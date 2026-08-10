//// Runtime syntax-highlighting effect.
////
//// Markdown code blocks are rendered at build time by mork and stored as plain
//// `<pre><code>` HTML in `content_index.json`. This effect enhances those
//// blocks after Lustre mounts the rendered content.
////
//// The JavaScript implementation:
////
////   - skips loading the runtime when highlighting is disabled
////   - skips loading when no eligible code blocks exist
////   - loads the configured Highlight.js browser bundle at most once
////   - highlights newly mounted code blocks after SPA navigation
////   - leaves Mermaid and plain-text blocks untouched
////   - fails open when the runtime cannot be loaded
////
//// The configured URL must point to a browser-compatible Highlight.js bundle
//// that exposes `globalThis.hljs`, such as the prebuilt `highlight.min.js`
//// distributed by Highlight.js.
////
//// Syntax highlighting and code-block controls are separate enhancements.
//// This effect tokenizes source code, while `effect/codeblock.gleam` adds copy
//// buttons, language labels, and horizontal-scroll behavior.

import lustre/effect.{type Effect}

/// Highlight eligible code blocks after rendered Markdown enters the DOM.
///
/// When disabled, this returns no effects and does not call the JavaScript FFI.
/// The FFI is responsible for avoiding unnecessary network requests when the
/// current document contains no eligible code blocks.
///
/// `grammar_map` is a normalized language-to-URL map for on-demand grammar
/// loading. Languages already registered by the runtime are highlighted
/// immediately; unregistered languages trigger a grammar script load before
/// being marked unsupported.
pub fn enhance(enabled: Bool, cdn_url: String, grammar_map: List(#(String, String))) -> Effect(Nil) {
  case enabled {
    False -> effect.none()

    True -> {
      use _ <- effect.from
      enhance_code_blocks(cdn_url, grammar_map)
      Nil
    }
  }
}

/// Load the configured Highlight.js runtime and highlight mounted code blocks.
///
/// The fallback body keeps non-JavaScript targets buildable without performing
/// any syntax-highlighting work.
@external(javascript, "../ffi/syntax_highlight.ffi.mjs", "enhance_code_blocks")
fn enhance_code_blocks(_cdn_url: String, _grammar_map: List(#(String, String))) -> Nil {
  Nil
}
